import Foundation

nonisolated struct SocketDockerResourceService: DockerResourceProviding {
    typealias ClientFactory = @Sendable (String) -> any DockerEngineAPIClient

    private let clientFactory: ClientFactory
    private let now: @Sendable () -> Date

    init(
        clientFactory: @escaping ClientFactory = { DockerUDSClient(socketPath: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.clientFactory = clientFactory
        self.now = now
    }

    func loadSnapshot(socketPath: String) async -> ResourceLoadState<DockerResourceSnapshot> {
        guard !DockerUDSClient.normalizedSocketPath(socketPath).isEmpty else {
            return .failed(
                BackendIssue(
                    severity: .error,
                    source: .docker,
                    title: "Unable to load Docker resources",
                    message: "Docker socket path is empty.",
                    recoverySuggestion: "Check that Colima is running and exposes a Docker socket."
                ),
                lastValue: nil
            )
        }

        do {
            return .loaded(try await snapshot(socketPath: socketPath), updatedAt: now())
        } catch {
            return .failed(
                BackendIssue(
                    severity: .error,
                    source: .docker,
                    title: "Unable to load Docker resources",
                    message: error.localizedDescription,
                    recoverySuggestion: "Check that Colima is running and the Docker socket path is valid."
                ),
                lastValue: nil
            )
        }
    }

    func snapshot(socketPath: String) async throws -> DockerResourceSnapshot {
        guard !DockerUDSClient.normalizedSocketPath(socketPath).isEmpty else {
            throw DockerSocketResourceServiceError.emptySocketPath
        }

        let collectedAt = now()
        let client = clientFactory(socketPath)

        async let containersResult = containers(client: client)
        async let imagesResult = images(client: client)
        async let volumesResult = volumes(client: client)
        async let networksResult = networks(client: client)
        async let diskUsageResult = diskUsage(client: client)

        let containers = await containersResult
        let images = await imagesResult
        let volumes = await volumesResult
        let networks = await networksResult
        let diskUsage = await diskUsageResult
        let stats = await stats(for: containers.value, client: client)

        var issues = containers.issues + images.issues + volumes.issues + networks.issues + diskUsage.issues + stats.issues
        if containers.value.contains(where: { $0.state.lowercased() == "dead" }) {
            issues.append(
                BackendIssue(
                    severity: .warning,
                    source: .docker,
                    title: "Dead Docker containers detected",
                    message: "One or more containers are in the dead state."
                )
            )
        }

        return DockerResourceSnapshot(
            context: Self.contextName(from: socketPath),
            collectedAt: collectedAt,
            containers: containers.value,
            images: images.value,
            volumes: volumes.value,
            networks: networks.value,
            stats: stats.value,
            diskUsage: diskUsage.value,
            issues: issues,
            commandRuns: []
        )
    }

    private func containers(client: any DockerEngineAPIClient) async -> SectionResult<[DockerContainerResource]> {
        do {
            let response = try await client.decode(
                [EngineContainer].self,
                path: "/containers/json",
                queryItems: [DockerUDSQueryItem(name: "all", value: "1")]
            )
            return SectionResult(value: response.compactMap(Self.container), issues: [])
        } catch {
            return SectionResult(value: [], issues: [issue(title: "List Docker containers", source: .docker, error: error)])
        }
    }

    private func images(client: any DockerEngineAPIClient) async -> SectionResult<[DockerImageResource]> {
        do {
            let response = try await client.decode(
                [EngineImage].self,
                path: "/images/json",
                queryItems: [DockerUDSQueryItem(name: "digests", value: "1")]
            )
            return SectionResult(value: response.compactMap(Self.image), issues: [])
        } catch {
            return SectionResult(value: [], issues: [issue(title: "List Docker images", source: .docker, error: error)])
        }
    }

    private func volumes(client: any DockerEngineAPIClient) async -> SectionResult<[DockerVolumeResource]> {
        do {
            let response = try await client.decode(EngineVolumeList.self, path: "/volumes")
            return SectionResult(value: (response.volumes ?? []).compactMap(Self.volume), issues: [])
        } catch {
            return SectionResult(value: [], issues: [issue(title: "List Docker volumes", source: .docker, error: error)])
        }
    }

    private func networks(client: any DockerEngineAPIClient) async -> SectionResult<[DockerNetworkResource]> {
        do {
            let response = try await client.decode([EngineNetwork].self, path: "/networks")
            return SectionResult(value: response.compactMap(Self.network), issues: [])
        } catch {
            return SectionResult(value: [], issues: [issue(title: "List Docker networks", source: .docker, error: error)])
        }
    }

    private func diskUsage(client: any DockerEngineAPIClient) async -> SectionResult<[DockerDiskUsageResource]> {
        do {
            let response = try await client.decode(EngineDiskUsage.self, path: "/system/df")
            return SectionResult(value: Self.diskUsage(response), issues: [])
        } catch {
            return SectionResult(value: [], issues: [issue(title: "Read Docker disk usage", source: .metrics, error: error)])
        }
    }

    private func stats(
        for containers: [DockerContainerResource],
        client: any DockerEngineAPIClient
    ) async -> SectionResult<[DockerStatsResource]> {
        let running = containers.filter { $0.state.lowercased() == "running" }
        guard !running.isEmpty else {
            return SectionResult(value: [], issues: [])
        }

        return await withTaskGroup(of: StatFetchResult.self, returning: SectionResult<[DockerStatsResource]>.self) { group in
            var nextIndex = 0
            let initialCount = min(8, running.count)
            for _ in 0..<initialCount {
                let container = running[nextIndex]
                nextIndex += 1
                group.addTask {
                    await Self.stat(container: container, client: client)
                }
            }

            var values: [DockerStatsResource] = []
            var issues: [BackendIssue] = []
            while let result = await group.next() {
                switch result {
                case let .success(stats):
                    values.append(stats)
                case let .failure(issue):
                    issues.append(issue)
                }

                if nextIndex < running.count {
                    let container = running[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        await Self.stat(container: container, client: client)
                    }
                }
            }

            return SectionResult(value: values, issues: issues)
        }
    }

    private nonisolated static func stat(
        container: DockerContainerResource,
        client: any DockerEngineAPIClient
    ) async -> StatFetchResult {
        do {
            let response = try await client.decode(
                EngineStats.self,
                path: "/containers/\(urlPathComponent(container.id))/stats",
                queryItems: [DockerUDSQueryItem(name: "stream", value: "false")]
            )
            return .success(Self.stats(response, fallback: container))
        } catch {
            return .failure(
                BackendIssue(
                    severity: .warning,
                    source: .metrics,
                    title: "Read Docker container stats",
                    message: "Unable to read stats for \(container.name): \(error.localizedDescription)"
                )
            )
        }
    }

    private nonisolated func issue(title: String, source: BackendIssueSource, error: Error) -> BackendIssue {
        BackendIssue(
            severity: .warning,
            source: source,
            title: title,
            message: error.localizedDescription
        )
    }

    private nonisolated static func container(_ value: EngineContainer) -> DockerContainerResource? {
        let id = value.id ?? ""
        let name = cleanContainerName(value.names?.first ?? "")
        guard !id.isEmpty || !name.isEmpty else { return nil }
        let portBindings = (value.ports ?? []).compactMap(Self.portBinding)
        return DockerContainerResource(
            id: id.isEmpty ? name : id,
            name: name.isEmpty ? String(id.prefix(12)) : name,
            image: value.image ?? "",
            command: value.command ?? "",
            createdAt: formatTimestamp(value.created),
            runningFor: "",
            ports: portsDescription(value.ports ?? []),
            state: value.state ?? "",
            status: value.status ?? "",
            size: formatContainerSize(rw: value.sizeRw, rootFs: value.sizeRootFs),
            labels: value.labels ?? [:],
            portBindings: portBindings
        )
    }

    private nonisolated static func image(_ value: EngineImage) -> DockerImageResource? {
        let id = value.id ?? ""
        guard !id.isEmpty || value.repoTags?.isEmpty == false else { return nil }
        let repoTag = splitRepoTag(value.repoTags?.first ?? "")
        return DockerImageResource(
            id: id.isEmpty ? "\(repoTag.repository):\(repoTag.tag)" : id,
            repository: repoTag.repository,
            tag: repoTag.tag,
            digest: digest(from: value.repoDigests?.first ?? ""),
            createdAt: formatTimestamp(value.created),
            createdSince: "",
            size: formatBytes(value.size)
        )
    }

    private nonisolated static func volume(_ value: EngineVolume) -> DockerVolumeResource? {
        guard let name = value.name, !name.isEmpty else { return nil }
        return DockerVolumeResource(
            name: name,
            driver: value.driver ?? "",
            scope: value.scope ?? "",
            mountpoint: value.mountpoint ?? "",
            labels: value.labels ?? [:]
        )
    }

    private nonisolated static func network(_ value: EngineNetwork) -> DockerNetworkResource? {
        let id = value.id ?? ""
        let name = value.name ?? ""
        guard !id.isEmpty || !name.isEmpty else { return nil }
        return DockerNetworkResource(
            id: id.isEmpty ? name : id,
            name: name,
            driver: value.driver ?? "",
            scope: value.scope ?? "",
            internalOnly: value.internalOnly ?? false,
            ipv6Enabled: value.ipv6Enabled ?? false
        )
    }

    private nonisolated static func diskUsage(_ value: EngineDiskUsage) -> [DockerDiskUsageResource] {
        [
            diskUsage(
                type: "Images",
                total: value.images?.count ?? 0,
                active: value.images?.filter { ($0.containers ?? 0) > 0 }.count ?? 0,
                size: value.images?.reduce(Int64(0)) { $0 + ($1.size ?? 0) } ?? 0,
                reclaimable: value.images?.filter { ($0.containers ?? 0) == 0 }.reduce(Int64(0)) { $0 + ($1.size ?? 0) } ?? 0
            ),
            diskUsage(
                type: "Containers",
                total: value.containers?.count ?? 0,
                active: value.containers?.filter { $0.state?.lowercased() == "running" }.count ?? 0,
                size: value.containers?.reduce(Int64(0)) { $0 + ($1.sizeRw ?? $1.sizeRootFs ?? 0) } ?? 0,
                reclaimable: value.containers?.filter { $0.state?.lowercased() != "running" }.reduce(Int64(0)) { $0 + ($1.sizeRw ?? $1.sizeRootFs ?? 0) } ?? 0
            ),
            diskUsage(
                type: "Volumes",
                total: value.volumes?.count ?? 0,
                active: value.volumes?.filter { ($0.usageData?.refCount ?? 0) > 0 }.count ?? 0,
                size: value.volumes?.reduce(Int64(0)) { $0 + ($1.usageData?.size ?? 0) } ?? 0,
                reclaimable: value.volumes?.filter { ($0.usageData?.refCount ?? 0) == 0 }.reduce(Int64(0)) { $0 + ($1.usageData?.size ?? 0) } ?? 0
            ),
            diskUsage(
                type: "Build Cache",
                total: value.buildCache?.count ?? 0,
                active: value.buildCache?.filter { $0.inUse == true }.count ?? 0,
                size: value.buildCache?.reduce(Int64(0)) { $0 + ($1.size ?? 0) } ?? 0,
                reclaimable: value.buildCache?.filter { $0.inUse != true }.reduce(Int64(0)) { $0 + ($1.size ?? 0) } ?? 0
            )
        ]
    }

    private nonisolated static func diskUsage(
        type: String,
        total: Int,
        active: Int,
        size: Int64,
        reclaimable: Int64
    ) -> DockerDiskUsageResource {
        DockerDiskUsageResource(
            type: type,
            totalCount: "\(total)",
            activeCount: "\(active)",
            size: formatBytes(size),
            reclaimable: "\(formatBytes(reclaimable)) (\(formatWholePercent(total: size, value: reclaimable)))"
        )
    }

    private nonisolated static func stats(_ value: EngineStats, fallback container: DockerContainerResource) -> DockerStatsResource {
        let id = value.id?.nonEmpty ?? container.id
        let name = cleanContainerName(value.name ?? "").nonEmpty ?? container.name
        let memoryUsage = value.memoryStats?.usage ?? 0
        let memoryLimit = value.memoryStats?.limit ?? 0
        return DockerStatsResource(
            id: id,
            name: name,
            cpuPercent: cpuPercent(value),
            memoryUsage: "\(formatBytes(Int64(memoryUsage))) / \(formatBytes(Int64(memoryLimit)))",
            memoryPercent: percent(memoryLimit == 0 ? 0 : Double(memoryUsage) / Double(memoryLimit) * 100),
            networkIO: networkIO(value.networks),
            blockIO: blockIO(value.blkioStats),
            pids: "\(value.pidsStats?.current ?? 0)"
        )
    }

    private nonisolated static func cpuPercent(_ value: EngineStats) -> String {
        let cpuTotal = value.cpuStats?.cpuUsage?.totalUsage ?? 0
        let previousCPUTotal = value.precpuStats?.cpuUsage?.totalUsage ?? 0
        let systemTotal = value.cpuStats?.systemCPUUsage ?? 0
        let previousSystemTotal = value.precpuStats?.systemCPUUsage ?? 0
        guard cpuTotal >= previousCPUTotal, systemTotal > previousSystemTotal else {
            return percent(0)
        }

        let cpuDelta = Double(cpuTotal - previousCPUTotal)
        let systemDelta = Double(systemTotal - previousSystemTotal)
        let onlineCPUs = value.cpuStats?.onlineCPUs
            ?? UInt64(value.cpuStats?.cpuUsage?.percpuUsage?.count ?? 1)
        return percent(cpuDelta / systemDelta * Double(max(onlineCPUs, 1)) * 100)
    }

    private nonisolated static func networkIO(_ networks: [String: EngineNetworkStats]?) -> String {
        let totals = (networks ?? [:]).values.reduce((rx: UInt64(0), tx: UInt64(0))) { result, value in
            (result.rx + (value.rxBytes ?? 0), result.tx + (value.txBytes ?? 0))
        }
        return "\(formatBytes(Int64(totals.rx))) / \(formatBytes(Int64(totals.tx)))"
    }

    private nonisolated static func blockIO(_ stats: EngineBlkioStats?) -> String {
        let totals = (stats?.ioServiceBytesRecursive ?? []).reduce((read: UInt64(0), write: UInt64(0))) { result, value in
            switch value.op?.lowercased() {
            case "read":
                return (result.read + (value.value ?? 0), result.write)
            case "write":
                return (result.read, result.write + (value.value ?? 0))
            default:
                return result
            }
        }
        return "\(formatBytes(Int64(totals.read))) / \(formatBytes(Int64(totals.write)))"
    }

    private nonisolated static func portBinding(_ port: EnginePort) -> DockerContainerResource.PortBinding? {
        guard let publicPort = port.publicPort, let privatePort = port.privatePort else { return nil }
        return DockerContainerResource.PortBinding(
            hostIP: port.ip?.nonEmpty ?? "localhost",
            hostPort: publicPort,
            containerPort: privatePort,
            proto: port.type?.lowercased() ?? "tcp"
        )
    }

    private nonisolated static func portsDescription(_ ports: [EnginePort]) -> String {
        ports.map { port in
            let proto = port.type?.lowercased() ?? "tcp"
            guard let privatePort = port.privatePort else { return "" }
            guard let publicPort = port.publicPort else { return "\(privatePort)/\(proto)" }
            let host = port.ip?.nonEmpty ?? "0.0.0.0"
            return "\(host):\(publicPort)->\(privatePort)/\(proto)"
        }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private nonisolated static func formatContainerSize(rw: Int64?, rootFs: Int64?) -> String {
        switch (rw, rootFs) {
        case let (.some(rw), .some(rootFs)):
            return "\(formatBytes(rw)) (virtual \(formatBytes(rootFs)))"
        case let (.some(rw), .none):
            return formatBytes(rw)
        case let (.none, .some(rootFs)):
            return formatBytes(rootFs)
        case (.none, .none):
            return ""
        }
    }

    private nonisolated static func splitRepoTag(_ value: String) -> (repository: String, tag: String) {
        guard !value.isEmpty else { return ("", "") }
        let slash = value.lastIndex(of: "/")
        let tagSearchStart = slash.map { value.index(after: $0) } ?? value.startIndex
        if let separator = value[tagSearchStart...].lastIndex(of: ":") {
            return (String(value[..<separator]), String(value[value.index(after: separator)...]))
        }
        return (value, "")
    }

    private nonisolated static func digest(from value: String) -> String {
        guard let separator = value.firstIndex(of: "@") else { return value }
        return String(value[value.index(after: separator)...])
    }

    private nonisolated static func cleanContainerName(_ value: String) -> String {
        String(value.drop { $0 == "/" })
    }

    private nonisolated static func formatTimestamp(_ timestamp: Int64?) -> String {
        guard let timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    private nonisolated static func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while abs(value) >= 1000, unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(bytes)\(units[unitIndex])"
        }
        let format = abs(value) >= 10 ? "%.0f%@" : "%.1f%@"
        return String(format: format, locale: Locale(identifier: "en_US_POSIX"), value, units[unitIndex])
    }

    private nonisolated static func percent(_ value: Double) -> String {
        String(format: "%.2f%%", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private nonisolated static func formatWholePercent(total: Int64, value: Int64) -> String {
        guard total > 0 else { return "0%" }
        return String(format: "%.0f%%", locale: Locale(identifier: "en_US_POSIX"), Double(value) / Double(total) * 100)
    }

    private nonisolated static func urlPathComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    nonisolated static func contextName(from socketPath: String) -> String {
        let path = DockerUDSClient.normalizedSocketPath(socketPath)
        let components = path.split(separator: "/").map(String.init)
        let profile: String?
        if let colimaIndex = components.lastIndex(where: { $0 == ".colima" || $0 == "colima" }),
           components.indices.contains(colimaIndex + 1) {
            profile = components[colimaIndex + 1]
        } else if components.last == "docker.sock", components.count >= 2 {
            profile = components[components.count - 2]
        } else {
            profile = nil
        }

        guard let profile, !profile.isEmpty else { return "" }
        return profile == "default" ? "colima" : "colima-\(profile)"
    }
}

private nonisolated enum DockerSocketResourceServiceError: LocalizedError {
    case emptySocketPath

    var errorDescription: String? {
        switch self {
        case .emptySocketPath:
            return "Docker socket path is empty."
        }
    }
}

private nonisolated struct SectionResult<Value: Sendable>: Sendable {
    var value: Value
    var issues: [BackendIssue]
}

private nonisolated enum StatFetchResult: Sendable {
    case success(DockerStatsResource)
    case failure(BackendIssue)
}

private nonisolated struct EngineContainer: Decodable, Sendable {
    var id: String?
    var names: [String]?
    var image: String?
    var command: String?
    var created: Int64?
    var ports: [EnginePort]?
    var state: String?
    var status: String?
    var labels: [String: String]?
    var sizeRw: Int64?
    var sizeRootFs: Int64?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case names = "Names"
        case image = "Image"
        case command = "Command"
        case created = "Created"
        case ports = "Ports"
        case state = "State"
        case status = "Status"
        case labels = "Labels"
        case sizeRw = "SizeRw"
        case sizeRootFs = "SizeRootFs"
    }
}

private nonisolated struct EnginePort: Decodable, Sendable {
    var ip: String?
    var privatePort: Int?
    var publicPort: Int?
    var type: String?

    enum CodingKeys: String, CodingKey {
        case ip = "IP"
        case privatePort = "PrivatePort"
        case publicPort = "PublicPort"
        case type = "Type"
    }
}

private nonisolated struct EngineImage: Decodable, Sendable {
    var id: String?
    var repoTags: [String]?
    var repoDigests: [String]?
    var created: Int64?
    var size: Int64?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case repoTags = "RepoTags"
        case repoDigests = "RepoDigests"
        case created = "Created"
        case size = "Size"
    }
}

private nonisolated struct EngineVolumeList: Decodable, Sendable {
    var volumes: [EngineVolume]?

    enum CodingKeys: String, CodingKey {
        case volumes = "Volumes"
    }
}

private nonisolated struct EngineVolume: Decodable, Sendable {
    var name: String?
    var driver: String?
    var scope: String?
    var mountpoint: String?
    var labels: [String: String]?
    var usageData: EngineVolumeUsage?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case driver = "Driver"
        case scope = "Scope"
        case mountpoint = "Mountpoint"
        case labels = "Labels"
        case usageData = "UsageData"
    }
}

private nonisolated struct EngineVolumeUsage: Decodable, Sendable {
    var size: Int64?
    var refCount: Int?

    enum CodingKeys: String, CodingKey {
        case size = "Size"
        case refCount = "RefCount"
    }
}

private nonisolated struct EngineNetwork: Decodable, Sendable {
    var id: String?
    var name: String?
    var driver: String?
    var scope: String?
    var internalOnly: Bool?
    var ipv6Enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case driver = "Driver"
        case scope = "Scope"
        case internalOnly = "Internal"
        case ipv6Enabled = "EnableIPv6"
    }
}

private nonisolated struct EngineDiskUsage: Decodable, Sendable {
    var images: [EngineDiskImage]?
    var containers: [EngineDiskContainer]?
    var volumes: [EngineVolume]?
    var buildCache: [EngineBuildCache]?

    enum CodingKeys: String, CodingKey {
        case images = "Images"
        case containers = "Containers"
        case volumes = "Volumes"
        case buildCache = "BuildCache"
    }
}

private nonisolated struct EngineDiskImage: Decodable, Sendable {
    var size: Int64?
    var containers: Int?

    enum CodingKeys: String, CodingKey {
        case size = "Size"
        case containers = "Containers"
    }
}

private nonisolated struct EngineDiskContainer: Decodable, Sendable {
    var state: String?
    var sizeRw: Int64?
    var sizeRootFs: Int64?

    enum CodingKeys: String, CodingKey {
        case state = "State"
        case sizeRw = "SizeRw"
        case sizeRootFs = "SizeRootFs"
    }
}

private nonisolated struct EngineBuildCache: Decodable, Sendable {
    var size: Int64?
    var inUse: Bool?

    enum CodingKeys: String, CodingKey {
        case size = "Size"
        case inUse = "InUse"
    }
}

private nonisolated struct EngineStats: Decodable, Sendable {
    var id: String?
    var name: String?
    var cpuStats: EngineCPUStats?
    var precpuStats: EngineCPUStats?
    var memoryStats: EngineMemoryStats?
    var networks: [String: EngineNetworkStats]?
    var blkioStats: EngineBlkioStats?
    var pidsStats: EnginePidsStats?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cpuStats = "cpu_stats"
        case precpuStats = "precpu_stats"
        case memoryStats = "memory_stats"
        case networks
        case blkioStats = "blkio_stats"
        case pidsStats = "pids_stats"
    }
}

private nonisolated struct EngineCPUStats: Decodable, Sendable {
    var cpuUsage: EngineCPUUsage?
    var systemCPUUsage: UInt64?
    var onlineCPUs: UInt64?

    enum CodingKeys: String, CodingKey {
        case cpuUsage = "cpu_usage"
        case systemCPUUsage = "system_cpu_usage"
        case onlineCPUs = "online_cpus"
    }
}

private nonisolated struct EngineCPUUsage: Decodable, Sendable {
    var totalUsage: UInt64?
    var percpuUsage: [UInt64]?

    enum CodingKeys: String, CodingKey {
        case totalUsage = "total_usage"
        case percpuUsage = "percpu_usage"
    }
}

private nonisolated struct EngineMemoryStats: Decodable, Sendable {
    var usage: UInt64?
    var limit: UInt64?
}

private nonisolated struct EngineNetworkStats: Decodable, Sendable {
    var rxBytes: UInt64?
    var txBytes: UInt64?

    enum CodingKeys: String, CodingKey {
        case rxBytes = "rx_bytes"
        case txBytes = "tx_bytes"
    }
}

private nonisolated struct EngineBlkioStats: Decodable, Sendable {
    var ioServiceBytesRecursive: [EngineBlkioEntry]?

    enum CodingKeys: String, CodingKey {
        case ioServiceBytesRecursive = "io_service_bytes_recursive"
    }
}

private nonisolated struct EngineBlkioEntry: Decodable, Sendable {
    var op: String?
    var value: UInt64?

    enum CodingKeys: String, CodingKey {
        case op
        case value
    }
}

private nonisolated struct EnginePidsStats: Decodable, Sendable {
    var current: Int?
}
