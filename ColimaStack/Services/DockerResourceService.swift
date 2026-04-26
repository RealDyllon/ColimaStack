import Foundation

protocol DockerResourceProviding {
    func loadSnapshot(context: String?) async -> ResourceLoadState<DockerResourceSnapshot>
    func snapshot(context: String?) async throws -> DockerResourceSnapshot
}

struct LiveDockerResourceService: DockerResourceProviding {
    private let commandRunner: CommandRunProviding

    init(commandRunner: CommandRunProviding = LiveCommandRunService()) {
        self.commandRunner = commandRunner
    }

    func loadSnapshot(context: String? = nil) async -> ResourceLoadState<DockerResourceSnapshot> {
        do {
            return .loaded(try await snapshot(context: context), updatedAt: Date())
        } catch {
            return .failed(
                BackendIssue(
                    severity: .error,
                    source: .docker,
                    title: "Unable to load Docker resources",
                    message: error.localizedDescription,
                    recoverySuggestion: "Check that Colima is running and the Docker CLI is installed."
                ),
                lastValue: nil
            )
        }
    }

    func snapshot(context: String? = nil) async throws -> DockerResourceSnapshot {
        let collectedAt = Date()
        async let activeContextResult = collectStringResult(
            context: context,
            arguments: ["context", "show"],
            purpose: "Read active Docker context"
        )
        async let containersResult = collectJSONLinesResult(
            context: context,
            arguments: ["ps", "--all", "--no-trunc", "--format", "{{json .}}"],
            purpose: "List Docker containers",
            source: BackendIssueSource.docker,
            transform: Self.container
        )
        async let imagesResult = collectJSONLinesResult(
            context: context,
            arguments: ["images", "--digests", "--no-trunc", "--format", "{{json .}}"],
            purpose: "List Docker images",
            source: BackendIssueSource.docker,
            transform: Self.image
        )
        async let volumesResult = collectJSONLinesResult(
            context: context,
            arguments: ["volume", "ls", "--format", "{{json .}}"],
            purpose: "List Docker volumes",
            source: BackendIssueSource.docker,
            transform: Self.volume
        )
        async let networksResult = collectJSONLinesResult(
            context: context,
            arguments: ["network", "ls", "--no-trunc", "--format", "{{json .}}"],
            purpose: "List Docker networks",
            source: BackendIssueSource.docker,
            transform: Self.network
        )
        async let statsResult = collectJSONLinesResult(
            context: context,
            arguments: ["stats", "--no-stream", "--format", "{{json .}}"],
            purpose: "Read Docker container stats",
            source: BackendIssueSource.metrics,
            transform: Self.stats
        )
        async let diskUsageResult = collectJSONLinesResult(
            context: context,
            arguments: ["system", "df", "--format", "{{json .}}"],
            purpose: "Read Docker disk usage",
            source: BackendIssueSource.metrics,
            transform: Self.diskUsage
        )

        let activeContext = await activeContextResult
        let containers = await containersResult
        let images = await imagesResult
        let volumes = await volumesResult
        let networks = await networksResult
        let stats = await statsResult
        let diskUsage = await diskUsageResult

        var issues = activeContext.issues + containers.issues + images.issues + volumes.issues + networks.issues + stats.issues + diskUsage.issues
        let runs = activeContext.runs + containers.runs + images.runs + volumes.runs + networks.runs + stats.runs + diskUsage.runs

        if containers.values.contains(where: { $0.state.lowercased() == "dead" }) {
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
            context: activeContext.value ?? context ?? "",
            collectedAt: collectedAt,
            containers: containers.values,
            images: images.values,
            volumes: volumes.values,
            networks: networks.values,
            stats: stats.values,
            diskUsage: diskUsage.values,
            issues: issues,
            commandRuns: runs
        )
    }

    private func collectStringResult(
        context: String?,
        arguments: [String],
        purpose: String
    ) async -> (value: String?, issues: [BackendIssue], runs: [ManagedCommandRun]) {
        var issues: [BackendIssue] = []
        guard let run = await runDocker(context: context, arguments: arguments, purpose: purpose, issues: &issues) else {
            return (nil, issues, [])
        }
        guard run.succeeded else {
            issues.append(issue(for: run, source: .docker, title: purpose))
            return (nil, issues, [run])
        }
        return (run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines), issues, [run])
    }

    private func collectJSONLinesResult<Value>(
        context: String?,
        arguments: [String],
        purpose: String,
        source: BackendIssueSource,
        transform: ([String: Any]) -> Value?
    ) async -> (values: [Value], issues: [BackendIssue], runs: [ManagedCommandRun]) {
        var issues: [BackendIssue] = []
        guard let run = await runDocker(context: context, arguments: arguments, purpose: purpose, issues: &issues) else {
            return ([], issues, [])
        }
        guard run.succeeded else {
            issues.append(issue(for: run, source: source, title: purpose))
            return ([], issues, [run])
        }
        let parsed = JSONCommandParser.parseJSONLines(run.standardOutput)
        if !parsed.malformedLineNumbers.isEmpty {
            issues.append(
                BackendIssue(
                    severity: .warning,
                    source: source,
                    title: purpose,
                    message: "Dropped \(parsed.malformedLineNumbers.count) malformed JSON line(s): \(parsed.malformedLineNumbers.map(String.init).joined(separator: ", ")).",
                    command: run.commandString
                )
            )
        }

        var values: [Value] = []
        var invalidRecords = 0
        for object in parsed.objects {
            if let value = transform(object) {
                values.append(value)
            } else {
                invalidRecords += 1
            }
        }
        if invalidRecords > 0 {
            issues.append(
                BackendIssue(
                    severity: .warning,
                    source: source,
                    title: purpose,
                    message: "Dropped \(invalidRecords) Docker resource record(s) with missing required fields.",
                    command: run.commandString
                )
            )
        }
        return (values, issues, [run])
    }

    private func runDocker(
        context: String?,
        arguments: [String],
        purpose: String,
        issues: inout [BackendIssue]
    ) async -> ManagedCommandRun? {
        do {
            return try await commandRunner.run(
                ManagedCommandRequest(
                    toolName: "docker",
                    arguments: dockerArguments(context: context, subcommand: arguments),
                    timeout: 15,
                    purpose: purpose
                )
            )
        } catch {
            issues.append(
                BackendIssue(
                    severity: .error,
                    source: .docker,
                    title: purpose,
                    message: error.localizedDescription,
                    recoverySuggestion: "Verify the Docker CLI is installed and reachable from PATH."
                )
            )
            return nil
        }
    }

    private func dockerArguments(context: String?, subcommand: [String]) -> [String] {
        guard let context, !context.isEmpty else { return subcommand }
        return ["--context", context] + subcommand
    }

    private func issue(for run: ManagedCommandRun, source: BackendIssueSource, title: String) -> BackendIssue {
        BackendIssue(
            severity: .warning,
            source: source,
            title: title,
            message: run.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Command exited with status \(run.terminationStatus).",
            command: run.commandString
        )
    }

    nonisolated private static func container(_ object: [String: Any]) -> DockerContainerResource? {
        let id = object.string("ID", "Id", "ContainerID")
        let name = object.string("Names", "Name")
        guard !id.isEmpty || !name.isEmpty else { return nil }
        return DockerContainerResource(
            id: id.isEmpty ? name : id,
            name: name,
            image: object.string("Image"),
            command: object.string("Command"),
            createdAt: object.string("CreatedAt"),
            runningFor: object.string("RunningFor"),
            ports: object.string("Ports"),
            state: object.string("State"),
            status: object.string("Status"),
            size: object.string("Size"),
            labels: object.labels("Labels"),
            portBindings: parsePortBindings(object.string("Ports"))
        )
    }

    nonisolated private static func parsePortBindings(_ ports: String) -> [DockerContainerResource.PortBinding] {
        ports
            .split(separator: ",")
            .compactMap { raw -> DockerContainerResource.PortBinding? in
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let arrow = value.range(of: "->") else { return nil }
                let host = String(value[..<arrow.lowerBound])
                let container = String(value[arrow.upperBound...])
                let hostParts = host.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
                guard let hostPortString = hostParts.last,
                      let hostPort = Int(hostPortString),
                      let containerPort = parseContainerPort(container) else {
                    return nil
                }
                let hostIP = hostParts.dropLast().joined(separator: ":").trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                return DockerContainerResource.PortBinding(
                    hostIP: hostIP.isEmpty ? "localhost" : hostIP,
                    hostPort: hostPort,
                    containerPort: containerPort.port,
                    proto: containerPort.proto
                )
            }
    }

    nonisolated private static func parseContainerPort(_ value: String) -> (port: Int, proto: String)? {
        let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
        guard let port = Int(parts.first ?? "") else { return nil }
        return (port, parts.dropFirst().first?.lowercased() ?? "tcp")
    }

    nonisolated private static func image(_ object: [String: Any]) -> DockerImageResource? {
        let id = object.string("ID", "Id")
        guard !id.isEmpty else { return nil }
        return DockerImageResource(
            id: id,
            repository: object.string("Repository"),
            tag: object.string("Tag"),
            digest: object.string("Digest"),
            createdAt: object.string("CreatedAt"),
            createdSince: object.string("CreatedSince"),
            size: object.string("Size")
        )
    }

    nonisolated private static func volume(_ object: [String: Any]) -> DockerVolumeResource? {
        let name = object.string("Name")
        guard !name.isEmpty else { return nil }
        return DockerVolumeResource(
            name: name,
            driver: object.string("Driver"),
            scope: object.string("Scope"),
            mountpoint: object.string("Mountpoint", "MountPoint"),
            labels: object.labels("Labels")
        )
    }

    nonisolated private static func network(_ object: [String: Any]) -> DockerNetworkResource? {
        let id = object.string("ID", "Id")
        let name = object.string("Name")
        guard !id.isEmpty || !name.isEmpty else { return nil }
        return DockerNetworkResource(
            id: id.isEmpty ? name : id,
            name: name,
            driver: object.string("Driver"),
            scope: object.string("Scope"),
            internalOnly: object.bool("Internal"),
            ipv6Enabled: object.bool("IPv6", "EnableIPv6")
        )
    }

    nonisolated private static func stats(_ object: [String: Any]) -> DockerStatsResource? {
        let id = object.string("Container", "ID")
        let name = object.string("Name")
        guard !id.isEmpty || !name.isEmpty else { return nil }
        return DockerStatsResource(
            id: id.isEmpty ? name : id,
            name: name,
            cpuPercent: object.string("CPUPerc"),
            memoryUsage: object.string("MemUsage"),
            memoryPercent: object.string("MemPerc"),
            networkIO: object.string("NetIO"),
            blockIO: object.string("BlockIO"),
            pids: object.string("PIDs")
        )
    }

    nonisolated private static func diskUsage(_ object: [String: Any]) -> DockerDiskUsageResource? {
        let type = object.string("Type")
        guard !type.isEmpty else { return nil }
        return DockerDiskUsageResource(
            type: type,
            totalCount: object.string("TotalCount"),
            activeCount: object.string("Active"),
            size: object.string("Size"),
            reclaimable: object.string("Reclaimable")
        )
    }
}
