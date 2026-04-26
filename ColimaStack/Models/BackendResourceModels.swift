import Foundation

nonisolated enum BackendResourceHealth: String, CaseIterable, Codable, Sendable {
    case healthy
    case warning
    case error
    case unknown
}

nonisolated enum BackendIssueSeverity: String, CaseIterable, Codable, Sendable {
    case info
    case warning
    case error
}

nonisolated enum BackendIssueSource: String, CaseIterable, Codable, Sendable {
    case colima
    case docker
    case kubernetes
    case metrics
    case command
    case tooling
}

nonisolated struct BackendIssue: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var severity: BackendIssueSeverity
    var source: BackendIssueSource
    var title: String
    var message: String
    var command: String?
    var recoverySuggestion: String?
    var detectedAt: Date

    init(
        id: UUID = UUID(),
        severity: BackendIssueSeverity,
        source: BackendIssueSource,
        title: String,
        message: String,
        command: String? = nil,
        recoverySuggestion: String? = nil,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.severity = severity
        self.source = source
        self.title = title
        self.message = message
        self.command = command
        self.recoverySuggestion = recoverySuggestion
        self.detectedAt = detectedAt
    }
}

nonisolated enum ResourceLoadState<Value> {
    case idle
    case loading(startedAt: Date)
    case loaded(Value, updatedAt: Date)
    case failed(BackendIssue, lastValue: Value?)

    var value: Value? {
        switch self {
        case let .loaded(value, _):
            return value
        case let .failed(_, lastValue):
            return lastValue
        case .idle, .loading:
            return nil
        }
    }
}

nonisolated struct BackendSearchQuery: Hashable, Codable, Sendable {
    var text: String
    var sources: Set<BackendIssueSource>
    var includeStopped: Bool

    init(text: String, sources: Set<BackendIssueSource> = Set(BackendIssueSource.allCases), includeStopped: Bool = true) {
        self.text = text
        self.sources = sources
        self.includeStopped = includeStopped
    }
}

nonisolated struct BackendSearchResult: Identifiable, Hashable, Codable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        case profile
        case container
        case image
        case volume
        case network
        case kubernetesNode
        case kubernetesNamespace
        case kubernetesPod
        case kubernetesService
        case kubernetesDeployment
        case issue
        case command
    }

    var id: String
    var kind: Kind
    var source: BackendIssueSource
    var title: String
    var subtitle: String
    var tokens: [String]
    var score: Double
    var profileState: ProfileState?

    init(
        id: String,
        kind: Kind,
        source: BackendIssueSource,
        title: String,
        subtitle: String,
        tokens: [String],
        score: Double,
        profileState: ProfileState? = nil
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.title = title
        self.subtitle = subtitle
        self.tokens = tokens
        self.score = score
        self.profileState = profileState
    }
}

nonisolated struct BackendSearchIndex: Hashable, Codable, Sendable {
    var collectedAt: Date
    var results: [BackendSearchResult]

    func search(_ query: BackendSearchQuery) -> [BackendSearchResult] {
        let visibleResults = results.filter { result in
            guard query.sources.contains(result.source) else { return false }
            guard !isStoppedColimaProfile(result) else { return query.includeStopped }
            return true
        }

        let terms = query.text
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !terms.isEmpty else {
            return visibleResults
        }

        return visibleResults
            .compactMap { result -> BackendSearchResult? in
                let haystack = ([result.title, result.subtitle] + result.tokens).joined(separator: " ").lowercased()
                let matches = terms.filter { haystack.contains($0) }.count
                guard matches > 0 else { return nil }
                var scored = result
                scored.score = Double(matches) / Double(terms.count)
                return scored
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.score > rhs.score
            }
    }

    private func isStoppedColimaProfile(_ result: BackendSearchResult) -> Bool {
        guard result.source == .colima, result.kind == .profile else { return false }
        return result.profileState == .stopped
    }
}

nonisolated struct ManagedCommandRequest: Hashable, Codable, Sendable {
    var toolName: String
    var arguments: [String]
    var environment: [String: String]
    var currentDirectoryPath: String?
    var standardInput: Data?
    var timeout: TimeInterval?
    var purpose: String

    init(
        toolName: String,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectoryPath: String? = nil,
        standardInput: Data? = nil,
        timeout: TimeInterval? = nil,
        purpose: String = ""
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.environment = environment
        self.currentDirectoryPath = currentDirectoryPath
        self.standardInput = standardInput
        self.timeout = timeout
        self.purpose = purpose
    }
}

nonisolated struct ManagedCommandRun: Identifiable, Hashable, Codable, Sendable, CombinedProcessOutput {
    var id: UUID
    var request: ManagedCommandRequest
    var executablePath: String
    var launchedAt: Date
    var duration: TimeInterval
    var terminationStatus: Int32
    var standardOutput: String
    var standardError: String

    init(
        id: UUID = UUID(),
        request: ManagedCommandRequest,
        executablePath: String,
        launchedAt: Date,
        duration: TimeInterval,
        terminationStatus: Int32,
        standardOutput: String,
        standardError: String
    ) {
        self.id = id
        self.request = request
        self.executablePath = executablePath
        self.launchedAt = launchedAt
        self.duration = duration
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    var commandString: String {
        if executablePath == "/usr/bin/env" {
            return ([executablePath, request.toolName] + request.arguments).joined(separator: " ")
        }
        return ([executablePath] + request.arguments).joined(separator: " ")
    }

    var succeeded: Bool {
        terminationStatus == 0
    }

}

nonisolated struct ResourceMetricSample: Identifiable, Hashable, Codable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        case cpu
        case memory
        case disk
        case networkReceive
        case networkTransmit
        case blockRead
        case blockWrite
        case processCount
    }

    var id: String
    var kind: Kind
    var ownerID: String
    var ownerName: String
    var value: Double
    var unit: String
    var collectedAt: Date
}

nonisolated struct RuntimeUsageSample: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var profileID: String
    var profileName: String
    var collectedAt: Date
    var cpuPercent: Double
    var memoryUsedBytes: Double
    var memoryLimitBytes: Double
    var diskUsedBytes: Double
    var diskLimitBytes: Double
    var networkReceiveBytes: Double
    var networkTransmitBytes: Double
    var blockReadBytes: Double
    var blockWriteBytes: Double
    var runningContainerCount: Int

    var memoryProgress: Double {
        Self.progress(memoryUsedBytes, against: memoryLimitBytes)
    }

    var diskProgress: Double {
        Self.progress(diskUsedBytes, against: diskLimitBytes)
    }

    private static func progress(_ value: Double, against maximum: Double) -> Double {
        guard maximum > 0 else { return 0 }
        return min(max(value / maximum, 0), 1)
    }
}

nonisolated struct DockerContainerResource: Identifiable, Hashable, Codable, Sendable {
    nonisolated struct PortBinding: Identifiable, Hashable, Codable, Sendable {
        var id: String { "\(hostIP):\(hostPort):\(containerPort)/\(proto)" }
        var hostIP: String
        var hostPort: Int
        var containerPort: Int
        var proto: String

        var browserURL: URL? {
            guard hostPort > 0 else { return nil }
            let scheme = containerPort == 443 || hostPort == 443 ? "https" : "http"
            return URL(string: "\(scheme)://localhost:\(hostPort)")
        }
    }

    var id: String
    var name: String
    var image: String
    var command: String
    var createdAt: String
    var runningFor: String
    var ports: String
    var state: String
    var status: String
    var size: String
    var labels: [String: String]
    var portBindings: [PortBinding]

    init(
        id: String,
        name: String,
        image: String,
        command: String,
        createdAt: String,
        runningFor: String,
        ports: String,
        state: String,
        status: String,
        size: String,
        labels: [String: String],
        portBindings: [PortBinding] = []
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.command = command
        self.createdAt = createdAt
        self.runningFor = runningFor
        self.ports = ports
        self.state = state
        self.status = status
        self.size = size
        self.labels = labels
        self.portBindings = portBindings
    }

    var health: BackendResourceHealth {
        let normalized = state.lowercased()
        if normalized == "running" { return .healthy }
        if normalized == "dead" { return .error }
        if normalized == "exited" || normalized == "restarting" || normalized == "paused" { return .warning }
        return .unknown
    }
}

nonisolated struct DockerImageResource: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var repository: String
    var tag: String
    var digest: String
    var createdAt: String
    var createdSince: String
    var size: String

    var displayName: String {
        [repository, tag].filter { !$0.isEmpty && $0 != "<none>" }.joined(separator: ":")
    }
}

nonisolated struct DockerVolumeResource: Identifiable, Hashable, Codable, Sendable {
    var id: String { name }
    var name: String
    var driver: String
    var scope: String
    var mountpoint: String
    var labels: [String: String]
}

nonisolated struct DockerNetworkResource: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var name: String
    var driver: String
    var scope: String
    var internalOnly: Bool
    var ipv6Enabled: Bool
}

nonisolated struct DockerStatsResource: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var name: String
    var cpuPercent: String
    var memoryUsage: String
    var memoryPercent: String
    var networkIO: String
    var blockIO: String
    var pids: String
}

nonisolated struct DockerDiskUsageResource: Hashable, Codable, Sendable {
    var type: String
    var totalCount: String
    var activeCount: String
    var size: String
    var reclaimable: String
}

nonisolated struct DockerResourceSnapshot: Hashable, Codable, Sendable {
    var context: String
    var collectedAt: Date
    var containers: [DockerContainerResource]
    var images: [DockerImageResource]
    var volumes: [DockerVolumeResource]
    var networks: [DockerNetworkResource]
    var stats: [DockerStatsResource]
    var diskUsage: [DockerDiskUsageResource]
    var issues: [BackendIssue]
    var commandRuns: [ManagedCommandRun]
}

nonisolated struct KubernetesObjectMetadata: Hashable, Codable, Sendable {
    var name: String
    var namespace: String?
    var uid: String
    var labels: [String: String]
    var creationTimestamp: Date?
}

nonisolated struct KubernetesNodeResource: Identifiable, Hashable, Codable, Sendable {
    var id: String { metadata.uid.isEmpty ? metadata.name : metadata.uid }
    var metadata: KubernetesObjectMetadata
    var roles: [String]
    var phase: String
    var kubeletVersion: String
    var internalIP: String
    var allocatableCPU: String
    var allocatableMemory: String
    var conditions: [String: String]

    var health: BackendResourceHealth {
        conditions["Ready"] == "True" ? .healthy : .warning
    }
}

nonisolated struct KubernetesNamespaceResource: Identifiable, Hashable, Codable, Sendable {
    var id: String { metadata.uid.isEmpty ? metadata.name : metadata.uid }
    var metadata: KubernetesObjectMetadata
    var phase: String
}

nonisolated struct KubernetesContainerStatusResource: Identifiable, Hashable, Codable, Sendable {
    var id: String { name }
    var name: String
    var image: String
    var ready: Bool
    var restartCount: Int
    var state: String
}

nonisolated struct KubernetesPodResource: Identifiable, Hashable, Codable, Sendable {
    var id: String { metadata.uid.isEmpty ? "\(metadata.namespace ?? "default")/\(metadata.name)" : metadata.uid }
    var metadata: KubernetesObjectMetadata
    var nodeName: String
    var phase: String
    var podIP: String
    var hostIP: String
    var containers: [KubernetesContainerStatusResource]

    var health: BackendResourceHealth {
        if phase == "Running", containers.allSatisfy(\.ready) { return .healthy }
        if phase == "Succeeded" { return .healthy }
        if phase == "Failed" { return .error }
        return .warning
    }
}

nonisolated struct KubernetesServiceResource: Identifiable, Hashable, Codable, Sendable {
    var id: String { metadata.uid.isEmpty ? "\(metadata.namespace ?? "default")/\(metadata.name)" : metadata.uid }
    var metadata: KubernetesObjectMetadata
    var type: String
    var clusterIP: String
    var externalIPs: [String]
    var ports: [String]
}

nonisolated struct KubernetesDeploymentResource: Identifiable, Hashable, Codable, Sendable {
    var id: String { metadata.uid.isEmpty ? "\(metadata.namespace ?? "default")/\(metadata.name)" : metadata.uid }
    var metadata: KubernetesObjectMetadata
    var desiredReplicas: Int
    var readyReplicas: Int
    var availableReplicas: Int
    var updatedReplicas: Int

    var health: BackendResourceHealth {
        desiredReplicas == readyReplicas && desiredReplicas == availableReplicas ? .healthy : .warning
    }
}

nonisolated struct KubernetesMetricResource: Identifiable, Hashable, Codable, Sendable {
    nonisolated enum OwnerKind: String, Codable, Sendable {
        case node
        case pod
    }

    var id: String
    var ownerKind: OwnerKind
    var namespace: String?
    var name: String
    var cpu: String
    var memory: String
}

nonisolated struct KubernetesResourceSnapshot: Hashable, Codable, Sendable {
    var context: String
    var collectedAt: Date
    var nodes: [KubernetesNodeResource]
    var namespaces: [KubernetesNamespaceResource]
    var pods: [KubernetesPodResource]
    var services: [KubernetesServiceResource]
    var deployments: [KubernetesDeploymentResource]
    var metrics: [KubernetesMetricResource]
    var issues: [BackendIssue]
    var commandRuns: [ManagedCommandRun]
}

nonisolated struct ColimaBackendSnapshot: Hashable, Codable, Sendable {
    var profile: ColimaProfile
    var status: ColimaStatusDetail
    var docker: DockerResourceSnapshot?
    var kubernetes: KubernetesResourceSnapshot?
    var metrics: [ResourceMetricSample]
    var issues: [BackendIssue]
    var collectedAt: Date

    func runtimeUsageSample() -> RuntimeUsageSample {
        let stats = docker?.stats ?? []
        let resources = profile.resources ?? status.resources
        let memoryLimitBytes = resources.map { Double($0.memoryGiB) * 1_073_741_824 } ?? stats.reduce(0) {
            $0 + ResourceQuantityParser.bytePair($1.memoryUsage).second
        }
        let diskLimitBytes = resources.map { Double($0.diskGiB) * 1_073_741_824 } ?? 0
        let networkIO = stats.reduce((receive: 0.0, transmit: 0.0)) { result, stat in
            let pair = ResourceQuantityParser.bytePair(stat.networkIO)
            return (result.receive + pair.first, result.transmit + pair.second)
        }
        let blockIO = stats.reduce((read: 0.0, write: 0.0)) { result, stat in
            let pair = ResourceQuantityParser.bytePair(stat.blockIO)
            return (result.read + pair.first, result.write + pair.second)
        }

        return RuntimeUsageSample(
            profileID: profile.id,
            profileName: profile.name,
            collectedAt: collectedAt,
            cpuPercent: stats.reduce(0) { $0 + ResourceQuantityParser.numericPrefix($1.cpuPercent) },
            memoryUsedBytes: stats.reduce(0) { $0 + ResourceQuantityParser.bytePair($1.memoryUsage).first },
            memoryLimitBytes: memoryLimitBytes,
            diskUsedBytes: docker?.diskUsage.reduce(0) { $0 + ResourceQuantityParser.bytes($1.size) } ?? 0,
            diskLimitBytes: diskLimitBytes,
            networkReceiveBytes: networkIO.receive,
            networkTransmitBytes: networkIO.transmit,
            blockReadBytes: blockIO.read,
            blockWriteBytes: blockIO.write,
            runningContainerCount: docker?.containers.filter { $0.state.lowercased() == "running" }.count ?? 0
        )
    }
}
