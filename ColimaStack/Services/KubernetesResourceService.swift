import Foundation

protocol KubernetesResourceProviding {
    func loadSnapshot(context: String?) async -> ResourceLoadState<KubernetesResourceSnapshot>
    func snapshot(context: String?) async throws -> KubernetesResourceSnapshot
}

struct LiveKubernetesResourceService: KubernetesResourceProviding {
    private let commandRunner: CommandRunProviding

    init(commandRunner: CommandRunProviding = LiveCommandRunService()) {
        self.commandRunner = commandRunner
    }

    func loadSnapshot(context: String? = nil) async -> ResourceLoadState<KubernetesResourceSnapshot> {
        do {
            return .loaded(try await snapshot(context: context), updatedAt: Date())
        } catch {
            return .failed(
                BackendIssue(
                    severity: .error,
                    source: .kubernetes,
                    title: "Unable to load Kubernetes resources",
                    message: error.localizedDescription,
                    recoverySuggestion: "Check that Kubernetes is enabled for the selected Colima profile and kubectl is installed."
                ),
                lastValue: nil
            )
        }
    }

    func snapshot(context: String? = nil) async throws -> KubernetesResourceSnapshot {
        let collectedAt = Date()
        async let discoveredContextResult = collectStringResult(
            context: context,
            arguments: ["config", "current-context"],
            purpose: "Read active Kubernetes context"
        )

        async let nodesResult = collectListResult(
            context: context,
            arguments: ["get", "nodes", "-o", "json"],
            purpose: "List Kubernetes nodes",
            transform: Self.node
        )
        async let namespacesResult = collectListResult(
            context: context,
            arguments: ["get", "namespaces", "-o", "json"],
            purpose: "List Kubernetes namespaces",
            transform: Self.namespace
        )
        async let podsResult = collectListResult(
            context: context,
            arguments: ["get", "pods", "--all-namespaces", "-o", "json"],
            purpose: "List Kubernetes pods",
            transform: Self.pod
        )
        async let servicesResult = collectListResult(
            context: context,
            arguments: ["get", "services", "--all-namespaces", "-o", "json"],
            purpose: "List Kubernetes services",
            transform: Self.service
        )
        async let deploymentsResult = collectListResult(
            context: context,
            arguments: ["get", "deployments", "--all-namespaces", "-o", "json"],
            purpose: "List Kubernetes deployments",
            transform: Self.deployment
        )
        async let metricsResult = collectMetricsResult(context: context)

        let discoveredContext = await discoveredContextResult
        let nodes = await nodesResult
        let namespaces = await namespacesResult
        let pods = await podsResult
        let services = await servicesResult
        let deployments = await deploymentsResult
        let metrics = await metricsResult

        let activeContext = context ?? discoveredContext.value ?? ""
        var issues = discoveredContext.issues + nodes.issues + namespaces.issues + pods.issues + services.issues + deployments.issues + metrics.issues
        let runs = discoveredContext.runs + nodes.runs + namespaces.runs + pods.runs + services.runs + deployments.runs + metrics.runs

        if runs.isEmpty, let issue = issues.first(where: { $0.severity == .error }) {
            throw KubernetesResourceServiceError.unavailable(issue.message)
        }

        issues.append(contentsOf: pods.values.compactMap { pod in
            pod.health == .error ? BackendIssue(
                severity: .error,
                source: .kubernetes,
                title: "Pod failed",
                message: "\(pod.metadata.namespace ?? "default")/\(pod.metadata.name) is in phase \(pod.phase)."
            ) : nil
        })
        issues.append(contentsOf: deployments.values.compactMap { deployment in
            deployment.health == .warning ? BackendIssue(
                severity: .warning,
                source: .kubernetes,
                title: "Deployment not fully available",
                message: "\(deployment.metadata.namespace ?? "default")/\(deployment.metadata.name) has \(deployment.availableReplicas)/\(deployment.desiredReplicas) replicas available."
            ) : nil
        })

        return KubernetesResourceSnapshot(
            context: activeContext,
            collectedAt: collectedAt,
            nodes: nodes.values,
            namespaces: namespaces.values,
            pods: pods.values,
            services: services.values,
            deployments: deployments.values,
            metrics: metrics.values,
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
        guard let run = await runKubectl(context: context, arguments: arguments, purpose: purpose, issues: &issues) else {
            return (nil, issues, [])
        }
        guard run.succeeded else {
            issues.append(issue(for: run, title: purpose, severity: .warning))
            return (nil, issues, [run])
        }
        return (run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines), issues, [run])
    }

    private func collectListResult<Value>(
        context: String?,
        arguments: [String],
        purpose: String,
        transform: ([String: Any]) -> Value?
    ) async -> (values: [Value], issues: [BackendIssue], runs: [ManagedCommandRun]) {
        var issues: [BackendIssue] = []
        guard let run = await runKubectl(context: context, arguments: arguments, purpose: purpose, issues: &issues) else {
            return ([], issues, [])
        }
        guard run.succeeded else {
            issues.append(issue(for: run, title: purpose, severity: .warning))
            return ([], issues, [run])
        }
        guard let object = JSONCommandParser.object(from: run.standardOutput) else {
            issues.append(
                BackendIssue(
                    severity: .warning,
                    source: .kubernetes,
                    title: "Unable to parse Kubernetes output",
                    message: "The command output for \(purpose) was not valid JSON.",
                    command: run.commandString
                )
            )
            return ([], issues, [run])
        }
        var values: [Value] = []
        for (index, item) in object.dictionaries("items").enumerated() {
            guard let value = transform(item) else {
                issues.append(
                    BackendIssue(
                        severity: .warning,
                        source: .kubernetes,
                        title: "Invalid Kubernetes resource item",
                        message: "The command output for \(purpose) included item \(index) without required metadata.name.",
                        command: run.commandString
                    )
                )
                continue
            }
            values.append(value)
        }
        return (values, issues, [run])
    }

    private func collectMetricsResult(
        context: String?
    ) async -> (values: [KubernetesMetricResource], issues: [BackendIssue], runs: [ManagedCommandRun]) {
        var issues: [BackendIssue] = []
        var runs: [ManagedCommandRun] = []
        var metrics: [KubernetesMetricResource] = []
        let nodeRun = await runKubectl(
            context: context,
            arguments: ["top", "nodes", "--no-headers"],
            purpose: "Read Kubernetes node metrics",
            issues: &issues
        )
        if let nodeRun {
            runs.append(nodeRun)
            if nodeRun.succeeded {
                metrics += parseNodeMetrics(nodeRun.standardOutput)
            } else {
                issues.append(issue(for: nodeRun, title: "Kubernetes node metrics unavailable", severity: .info))
            }
        }

        let podRun = await runKubectl(
            context: context,
            arguments: ["top", "pods", "--all-namespaces", "--no-headers"],
            purpose: "Read Kubernetes pod metrics",
            issues: &issues
        )
        if let podRun {
            runs.append(podRun)
            if podRun.succeeded {
                metrics += parsePodMetrics(podRun.standardOutput)
            } else {
                issues.append(issue(for: podRun, title: "Kubernetes pod metrics unavailable", severity: .info))
            }
        }
        return (metrics, issues, runs)
    }

    private func collectString(
        context: String?,
        arguments: [String],
        purpose: String,
        issues: inout [BackendIssue],
        runs: inout [ManagedCommandRun]
    ) async -> String? {
        let run = await runKubectl(context: context, arguments: arguments, purpose: purpose, issues: &issues)
        guard let run else { return nil }
        runs.append(run)
        guard run.succeeded else {
            issues.append(issue(for: run, title: purpose, severity: .warning))
            return nil
        }
        return run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func collectList<Value>(
        context: String?,
        arguments: [String],
        purpose: String,
        issues: inout [BackendIssue],
        runs: inout [ManagedCommandRun],
        transform: ([String: Any]) -> Value?
    ) async -> [Value] {
        let run = await runKubectl(context: context, arguments: arguments, purpose: purpose, issues: &issues)
        guard let run else { return [] }
        runs.append(run)
        guard run.succeeded else {
            issues.append(issue(for: run, title: purpose, severity: .warning))
            return []
        }
        guard let object = JSONCommandParser.object(from: run.standardOutput) else {
            issues.append(
                BackendIssue(
                    severity: .warning,
                    source: .kubernetes,
                    title: "Unable to parse Kubernetes output",
                    message: "The command output for \(purpose) was not valid JSON.",
                    command: run.commandString
                )
            )
            return []
        }
        return object.dictionaries("items").enumerated().compactMap { index, item in
            guard let value = transform(item) else {
                issues.append(
                    BackendIssue(
                        severity: .warning,
                        source: .kubernetes,
                        title: "Invalid Kubernetes resource item",
                        message: "The command output for \(purpose) included item \(index) without required metadata.name.",
                        command: run.commandString
                    )
                )
                return nil
            }
            return value
        }
    }

    private func collectMetrics(
        context: String?,
        issues: inout [BackendIssue],
        runs: inout [ManagedCommandRun]
    ) async -> [KubernetesMetricResource] {
        var metrics: [KubernetesMetricResource] = []
        let nodeRun = await runKubectl(
            context: context,
            arguments: ["top", "nodes", "--no-headers"],
            purpose: "Read Kubernetes node metrics",
            issues: &issues
        )
        if let nodeRun {
            runs.append(nodeRun)
            if nodeRun.succeeded {
                metrics += parseNodeMetrics(nodeRun.standardOutput)
            } else {
                issues.append(issue(for: nodeRun, title: "Kubernetes node metrics unavailable", severity: .info))
            }
        }

        let podRun = await runKubectl(
            context: context,
            arguments: ["top", "pods", "--all-namespaces", "--no-headers"],
            purpose: "Read Kubernetes pod metrics",
            issues: &issues
        )
        if let podRun {
            runs.append(podRun)
            if podRun.succeeded {
                metrics += parsePodMetrics(podRun.standardOutput)
            } else {
                issues.append(issue(for: podRun, title: "Kubernetes pod metrics unavailable", severity: .info))
            }
        }
        return metrics
    }

    private func runKubectl(
        context: String?,
        arguments: [String],
        purpose: String,
        issues: inout [BackendIssue]
    ) async -> ManagedCommandRun? {
        do {
            return try await commandRunner.run(
                ManagedCommandRequest(
                    toolName: "kubectl",
                    arguments: kubectlArguments(context: context, subcommand: arguments),
                    timeout: 20,
                    purpose: purpose
                )
            )
        } catch {
            issues.append(
                BackendIssue(
                    severity: .error,
                    source: .kubernetes,
                    title: purpose,
                    message: error.localizedDescription,
                    recoverySuggestion: "Verify kubectl is installed and the selected Colima Kubernetes context exists."
                )
            )
            return nil
        }
    }

    private func kubectlArguments(context: String?, subcommand: [String]) -> [String] {
        guard let context, !context.isEmpty else { return subcommand }
        return ["--context", context] + subcommand
    }

    private func issue(for run: ManagedCommandRun, title: String, severity: BackendIssueSeverity) -> BackendIssue {
        BackendIssue(
            severity: severity,
            source: .kubernetes,
            title: title,
            message: run.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Command exited with status \(run.terminationStatus).",
            command: run.commandString
        )
    }

    nonisolated private static func metadata(_ object: [String: Any]) -> KubernetesObjectMetadata {
        let metadata = object.dictionary("metadata")
        return KubernetesObjectMetadata(
            name: metadata.string("name"),
            namespace: metadata.string("namespace").nonEmpty,
            uid: metadata.string("uid"),
            labels: metadata.labels("labels"),
            creationTimestamp: parseDate(metadata.string("creationTimestamp"))
        )
    }

    nonisolated private static func node(_ object: [String: Any]) -> KubernetesNodeResource? {
        let metadata = metadata(object)
        guard !metadata.name.isEmpty else { return nil }
        let status = object.dictionary("status")
        let nodeInfo = status.dictionary("nodeInfo")
        let allocatable = status.dictionary("allocatable")
        let addresses = status.dictionaries("addresses")
        let conditions = status.dictionaries("conditions").reduce(into: [String: String]()) { result, condition in
            result[condition.string("type")] = condition.string("status")
        }
        let roles = metadata.labels.keys
            .filter { $0.hasPrefix("node-role.kubernetes.io/") }
            .map { $0.replacingOccurrences(of: "node-role.kubernetes.io/", with: "") }
            .sorted()
        return KubernetesNodeResource(
            metadata: metadata,
            roles: roles.isEmpty ? ["worker"] : roles,
            phase: status.string("phase"),
            kubeletVersion: nodeInfo.string("kubeletVersion"),
            internalIP: addresses.first(where: { $0.string("type") == "InternalIP" })?.string("address") ?? "",
            allocatableCPU: allocatable.string("cpu"),
            allocatableMemory: allocatable.string("memory"),
            conditions: conditions
        )
    }

    nonisolated private static func namespace(_ object: [String: Any]) -> KubernetesNamespaceResource? {
        let metadata = metadata(object)
        guard !metadata.name.isEmpty else { return nil }
        return KubernetesNamespaceResource(metadata: metadata, phase: object.dictionary("status").string("phase"))
    }

    nonisolated private static func pod(_ object: [String: Any]) -> KubernetesPodResource? {
        let metadata = metadata(object)
        guard !metadata.name.isEmpty else { return nil }
        let spec = object.dictionary("spec")
        let status = object.dictionary("status")
        let statuses = status.dictionaries("containerStatuses").map { item in
            KubernetesContainerStatusResource(
                name: item.string("name"),
                image: item.string("image"),
                ready: item.bool("ready"),
                restartCount: item.int("restartCount"),
                state: item.dictionary("state").keys.sorted().first ?? "unknown"
            )
        }
        return KubernetesPodResource(
            metadata: metadata,
            nodeName: spec.string("nodeName"),
            phase: status.string("phase"),
            podIP: status.string("podIP"),
            hostIP: status.string("hostIP"),
            containers: statuses
        )
    }

    nonisolated private static func service(_ object: [String: Any]) -> KubernetesServiceResource? {
        let metadata = metadata(object)
        guard !metadata.name.isEmpty else { return nil }
        let spec = object.dictionary("spec")
        let ports = spec.dictionaries("ports").map { port in
            [port.string("name"), port.string("port"), port.string("protocol")]
                .filter { !$0.isEmpty }
                .joined(separator: "/")
        }
        return KubernetesServiceResource(
            metadata: metadata,
            type: spec.string("type"),
            clusterIP: spec.string("clusterIP"),
            externalIPs: spec.stringArray("externalIPs"),
            ports: ports
        )
    }

    nonisolated private static func deployment(_ object: [String: Any]) -> KubernetesDeploymentResource? {
        let metadata = metadata(object)
        guard !metadata.name.isEmpty else { return nil }
        let spec = object.dictionary("spec")
        let status = object.dictionary("status")
        return KubernetesDeploymentResource(
            metadata: metadata,
            desiredReplicas: spec.int("replicas"),
            readyReplicas: status.int("readyReplicas"),
            availableReplicas: status.int("availableReplicas"),
            updatedReplicas: status.int("updatedReplicas")
        )
    }

    private func parseNodeMetrics(_ output: String) -> [KubernetesMetricResource] {
        output.components(separatedBy: .newlines).compactMap { line in
            let columns = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard columns.count >= 3 else { return nil }
            return KubernetesMetricResource(
                id: "node/\(columns[0])",
                ownerKind: .node,
                namespace: nil,
                name: columns[0],
                cpu: columns[1],
                memory: columns[2]
            )
        }
    }

    private func parsePodMetrics(_ output: String) -> [KubernetesMetricResource] {
        output.components(separatedBy: .newlines).compactMap { line in
            let columns = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard columns.count >= 4 else { return nil }
            return KubernetesMetricResource(
                id: "pod/\(columns[0])/\(columns[1])",
                ownerKind: .pod,
                namespace: columns[0],
                name: columns[1],
                cpu: columns[2],
                memory: columns[3]
            )
        }
    }

    nonisolated private static func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}

private enum KubernetesResourceServiceError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case let .unavailable(message):
            return message
        }
    }
}
