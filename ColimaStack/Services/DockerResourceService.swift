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
        var issues: [BackendIssue] = []
        var runs: [ManagedCommandRun] = []
        let collectedAt = Date()
        let activeContext = await collectString(
            context: context,
            arguments: ["context", "show"],
            purpose: "Read active Docker context",
            issues: &issues,
            runs: &runs
        ) ?? context ?? ""

        let containers = await collectJSONLines(
            context: context,
            arguments: ["ps", "--all", "--no-trunc", "--format", "{{json .}}"],
            purpose: "List Docker containers",
            source: BackendIssueSource.docker,
            issues: &issues,
            runs: &runs,
            transform: Self.container
        )
        let images = await collectJSONLines(
            context: context,
            arguments: ["images", "--digests", "--no-trunc", "--format", "{{json .}}"],
            purpose: "List Docker images",
            source: BackendIssueSource.docker,
            issues: &issues,
            runs: &runs,
            transform: Self.image
        )
        let volumes = await collectJSONLines(
            context: context,
            arguments: ["volume", "ls", "--format", "{{json .}}"],
            purpose: "List Docker volumes",
            source: BackendIssueSource.docker,
            issues: &issues,
            runs: &runs,
            transform: Self.volume
        )
        let networks = await collectJSONLines(
            context: context,
            arguments: ["network", "ls", "--no-trunc", "--format", "{{json .}}"],
            purpose: "List Docker networks",
            source: BackendIssueSource.docker,
            issues: &issues,
            runs: &runs,
            transform: Self.network
        )
        let stats = await collectJSONLines(
            context: context,
            arguments: ["stats", "--no-stream", "--format", "{{json .}}"],
            purpose: "Read Docker container stats",
            source: BackendIssueSource.metrics,
            issues: &issues,
            runs: &runs,
            transform: Self.stats
        )
        let diskUsage = await collectJSONLines(
            context: context,
            arguments: ["system", "df", "--format", "{{json .}}"],
            purpose: "Read Docker disk usage",
            source: BackendIssueSource.metrics,
            issues: &issues,
            runs: &runs,
            transform: Self.diskUsage
        )

        if containers.contains(where: { $0.state.lowercased() == "dead" }) {
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
            context: activeContext,
            collectedAt: collectedAt,
            containers: containers,
            images: images,
            volumes: volumes,
            networks: networks,
            stats: stats,
            diskUsage: diskUsage,
            issues: issues,
            commandRuns: runs
        )
    }

    private func collectString(
        context: String?,
        arguments: [String],
        purpose: String,
        issues: inout [BackendIssue],
        runs: inout [ManagedCommandRun]
    ) async -> String? {
        let run = await runDocker(context: context, arguments: arguments, purpose: purpose, issues: &issues)
        guard let run else { return nil }
        runs.append(run)
        guard run.succeeded else {
            issues.append(issue(for: run, source: .docker, title: purpose))
            return nil
        }
        return run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func collectJSONLines<Value>(
        context: String?,
        arguments: [String],
        purpose: String,
        source: BackendIssueSource,
        issues: inout [BackendIssue],
        runs: inout [ManagedCommandRun],
        transform: ([String: Any]) -> Value?
    ) async -> [Value] {
        let run = await runDocker(context: context, arguments: arguments, purpose: purpose, issues: &issues)
        guard let run else { return [] }
        runs.append(run)
        guard run.succeeded else {
            issues.append(issue(for: run, source: source, title: purpose))
            return []
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
        return values
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

    private static func container(_ object: [String: Any]) -> DockerContainerResource? {
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
            labels: object.labels("Labels")
        )
    }

    private static func image(_ object: [String: Any]) -> DockerImageResource? {
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

    private static func volume(_ object: [String: Any]) -> DockerVolumeResource? {
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

    private static func network(_ object: [String: Any]) -> DockerNetworkResource? {
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

    private static func stats(_ object: [String: Any]) -> DockerStatsResource? {
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

    private static func diskUsage(_ object: [String: Any]) -> DockerDiskUsageResource? {
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
