import Foundation

protocol BackendSearchIndexing {
    func index(profiles: [ColimaProfile], docker: DockerResourceSnapshot?, kubernetes: KubernetesResourceSnapshot?, commands: [ManagedCommandRun]) -> BackendSearchIndex
}

protocol MetricsCollecting {
    func metrics(profile: ColimaProfile, docker: DockerResourceSnapshot?, kubernetes: KubernetesResourceSnapshot?) -> [ResourceMetricSample]
}

struct BackendSearchIndexer: BackendSearchIndexing {
    func index(
        profiles: [ColimaProfile],
        docker: DockerResourceSnapshot? = nil,
        kubernetes: KubernetesResourceSnapshot? = nil,
        commands: [ManagedCommandRun] = []
    ) -> BackendSearchIndex {
        var results: [BackendSearchResult] = []

        results += profiles.map { profile in
            BackendSearchResult(
                id: "profile:\(profile.name)",
                kind: .profile,
                source: .colima,
                title: profile.name,
                subtitle: [profile.state.label, profile.runtime?.label ?? "", profile.dockerContext].filter { !$0.isEmpty }.joined(separator: " - "),
                tokens: [profile.name, profile.ipAddress, profile.socket, profile.rawSummary],
                score: 0,
                profileState: profile.state
            )
        }

        if let docker {
            results += docker.containers.map { container in
                BackendSearchResult(
                    id: "docker-container:\(container.id)",
                    kind: .container,
                    source: .docker,
                    title: container.name.isEmpty ? container.id : container.name,
                    subtitle: [container.image, container.state, container.status].filter { !$0.isEmpty }.joined(separator: " - "),
                    tokens: [container.id, container.image, container.command, container.ports] + Array(container.labels.keys) + Array(container.labels.values),
                    score: 0
                )
            }
            results += docker.images.map { image in
                BackendSearchResult(
                    id: "docker-image:\(image.id)",
                    kind: .image,
                    source: .docker,
                    title: image.displayName.isEmpty ? image.id : image.displayName,
                    subtitle: image.size,
                    tokens: [image.id, image.repository, image.tag, image.digest, image.createdAt, image.createdSince],
                    score: 0
                )
            }
            results += docker.volumes.map { volume in
                BackendSearchResult(
                    id: "docker-volume:\(volume.name)",
                    kind: .volume,
                    source: .docker,
                    title: volume.name,
                    subtitle: [volume.driver, volume.scope].filter { !$0.isEmpty }.joined(separator: " - "),
                    tokens: [volume.mountpoint] + Array(volume.labels.keys) + Array(volume.labels.values),
                    score: 0
                )
            }
            results += docker.networks.map { network in
                BackendSearchResult(
                    id: "docker-network:\(network.id)",
                    kind: .network,
                    source: .docker,
                    title: network.name,
                    subtitle: [network.driver, network.scope].filter { !$0.isEmpty }.joined(separator: " - "),
                    tokens: [network.id],
                    score: 0
                )
            }
            results += issueResults(docker.issues)
        }

        if let kubernetes {
            results += kubernetes.nodes.map { node in
                BackendSearchResult(
                    id: "kubernetes-node:\(node.id)",
                    kind: .kubernetesNode,
                    source: .kubernetes,
                    title: node.metadata.name,
                    subtitle: [node.kubeletVersion, node.internalIP, node.roles.joined(separator: ",")].filter { !$0.isEmpty }.joined(separator: " - "),
                    tokens: Array(node.metadata.labels.keys) + Array(node.metadata.labels.values),
                    score: 0
                )
            }
            results += kubernetes.namespaces.map { namespace in
                BackendSearchResult(
                    id: "kubernetes-namespace:\(namespace.id)",
                    kind: .kubernetesNamespace,
                    source: .kubernetes,
                    title: namespace.metadata.name,
                    subtitle: namespace.phase,
                    tokens: Array(namespace.metadata.labels.keys) + Array(namespace.metadata.labels.values),
                    score: 0
                )
            }
            results += kubernetes.pods.map { pod in
                BackendSearchResult(
                    id: "kubernetes-pod:\(pod.id)",
                    kind: .kubernetesPod,
                    source: .kubernetes,
                    title: pod.metadata.name,
                    subtitle: [pod.metadata.namespace ?? "", pod.phase, pod.nodeName].filter { !$0.isEmpty }.joined(separator: " - "),
                    tokens: [pod.podIP, pod.hostIP] + pod.containers.flatMap { [$0.name, $0.image, $0.state] },
                    score: 0
                )
            }
            results += kubernetes.services.map { service in
                BackendSearchResult(
                    id: "kubernetes-service:\(service.id)",
                    kind: .kubernetesService,
                    source: .kubernetes,
                    title: service.metadata.name,
                    subtitle: [service.metadata.namespace ?? "", service.type, service.clusterIP].filter { !$0.isEmpty }.joined(separator: " - "),
                    tokens: service.externalIPs + service.ports,
                    score: 0
                )
            }
            results += kubernetes.deployments.map { deployment in
                BackendSearchResult(
                    id: "kubernetes-deployment:\(deployment.id)",
                    kind: .kubernetesDeployment,
                    source: .kubernetes,
                    title: deployment.metadata.name,
                    subtitle: "\(deployment.readyReplicas)/\(deployment.desiredReplicas) ready",
                    tokens: [deployment.metadata.namespace ?? ""] + Array(deployment.metadata.labels.keys) + Array(deployment.metadata.labels.values),
                    score: 0
                )
            }
            results += issueResults(kubernetes.issues)
        }

        results += commands.map { run in
            BackendSearchResult(
                id: "command:\(run.id.uuidString)",
                kind: .command,
                source: .command,
                title: run.request.purpose.isEmpty ? run.request.toolName : run.request.purpose,
                subtitle: run.succeeded ? "Succeeded" : "Exited \(run.terminationStatus)",
                tokens: [run.commandString, run.standardOutput, run.standardError],
                score: 0
            )
        }

        return BackendSearchIndex(collectedAt: Date(), results: results.map { $0.redactingSecrets() })
    }

    private func issueResults(_ issues: [BackendIssue]) -> [BackendSearchResult] {
        issues.map { issue in
            BackendSearchResult(
                id: "issue:\(issue.id.uuidString)",
                kind: .issue,
                source: issue.source,
                title: issue.title,
                subtitle: issue.message,
                tokens: [issue.command ?? "", issue.recoverySuggestion ?? ""],
                score: 0
            )
        }
    }
}

private extension BackendSearchResult {
    func redactingSecrets() -> BackendSearchResult {
        var result = self
        result.title = EnvironmentRedactor.redacted(title)
        result.subtitle = EnvironmentRedactor.redacted(subtitle)
        result.tokens = EnvironmentRedactor.redacted(tokens)
        return result
    }
}

struct BackendMetricsCollector: MetricsCollecting {
    func metrics(
        profile: ColimaProfile,
        docker: DockerResourceSnapshot? = nil,
        kubernetes: KubernetesResourceSnapshot? = nil
    ) -> [ResourceMetricSample] {
        let collectedAt = Date()
        var samples: [ResourceMetricSample] = []
        if let resources = profile.resources {
            samples.append(ResourceMetricSample(id: "profile:\(profile.id):cpu", kind: .cpu, ownerID: profile.id, ownerName: profile.name, value: Double(resources.cpu), unit: "cores", collectedAt: collectedAt))
            samples.append(ResourceMetricSample(id: "profile:\(profile.id):memory", kind: .memory, ownerID: profile.id, ownerName: profile.name, value: Double(resources.memoryGiB), unit: "GiB", collectedAt: collectedAt))
            samples.append(ResourceMetricSample(id: "profile:\(profile.id):disk", kind: .disk, ownerID: profile.id, ownerName: profile.name, value: Double(resources.diskGiB), unit: "GiB", collectedAt: collectedAt))
        }

        if let docker {
            for stat in docker.stats {
                samples += dockerSamples(stat, collectedAt: collectedAt)
            }
        }

        if let kubernetes {
            for metric in kubernetes.metrics {
                samples.append(ResourceMetricSample(id: "\(metric.id):cpu", kind: .cpu, ownerID: metric.id, ownerName: metric.name, value: ResourceQuantityParser.numericPrefix(metric.cpu), unit: suffix(metric.cpu), collectedAt: collectedAt))
                samples.append(ResourceMetricSample(id: "\(metric.id):memory", kind: .memory, ownerID: metric.id, ownerName: metric.name, value: ResourceQuantityParser.numericPrefix(metric.memory), unit: suffix(metric.memory), collectedAt: collectedAt))
            }
        }

        return samples
    }

    private func dockerSamples(_ stats: DockerStatsResource, collectedAt: Date) -> [ResourceMetricSample] {
        let memory = ResourceQuantityParser.bytePair(stats.memoryUsage)
        let network = ResourceQuantityParser.bytePair(stats.networkIO)
        let block = ResourceQuantityParser.bytePair(stats.blockIO)
        var samples = [
            ResourceMetricSample(id: "docker:\(stats.id):cpu", kind: .cpu, ownerID: stats.id, ownerName: stats.name, value: ResourceQuantityParser.numericPrefix(stats.cpuPercent), unit: "%", collectedAt: collectedAt),
            ResourceMetricSample(id: "docker:\(stats.id):memory-percent", kind: .memory, ownerID: stats.id, ownerName: stats.name, value: ResourceQuantityParser.numericPrefix(stats.memoryPercent), unit: "%", collectedAt: collectedAt),
            ResourceMetricSample(id: "docker:\(stats.id):memory-used", kind: .memory, ownerID: stats.id, ownerName: stats.name, value: memory.first, unit: "bytes", collectedAt: collectedAt),
            ResourceMetricSample(id: "docker:\(stats.id):network-receive", kind: .networkReceive, ownerID: stats.id, ownerName: stats.name, value: network.first, unit: "bytes", collectedAt: collectedAt),
            ResourceMetricSample(id: "docker:\(stats.id):network-transmit", kind: .networkTransmit, ownerID: stats.id, ownerName: stats.name, value: network.second, unit: "bytes", collectedAt: collectedAt),
            ResourceMetricSample(id: "docker:\(stats.id):block-read", kind: .blockRead, ownerID: stats.id, ownerName: stats.name, value: block.first, unit: "bytes", collectedAt: collectedAt),
            ResourceMetricSample(id: "docker:\(stats.id):block-write", kind: .blockWrite, ownerID: stats.id, ownerName: stats.name, value: block.second, unit: "bytes", collectedAt: collectedAt)
        ]
        if let pids = Double(stats.pids) {
            samples.append(ResourceMetricSample(id: "docker:\(stats.id):pids", kind: .processCount, ownerID: stats.id, ownerName: stats.name, value: pids, unit: "pids", collectedAt: collectedAt))
        }
        return samples
    }

    private func suffix(_ value: String) -> String {
        let allowed = Set("0123456789.,")
        let suffix = value.drop { allowed.contains($0) }
        return suffix.isEmpty ? "count" : String(suffix)
    }
}

protocol BackendSnapshotProviding {
    func snapshot(profile: ColimaProfile, status: ColimaStatusDetail) async -> ColimaBackendSnapshot
}

struct LiveBackendSnapshotService: BackendSnapshotProviding {
    private let dockerService: DockerResourceProviding
    private let kubernetesService: KubernetesResourceProviding
    private let metricsCollector: MetricsCollecting

    init(
        dockerService: DockerResourceProviding = LiveDockerResourceService(),
        kubernetesService: KubernetesResourceProviding = LiveKubernetesResourceService(),
        metricsCollector: MetricsCollecting = BackendMetricsCollector()
    ) {
        self.dockerService = dockerService
        self.kubernetesService = kubernetesService
        self.metricsCollector = metricsCollector
    }

    func snapshot(profile: ColimaProfile, status: ColimaStatusDetail) async -> ColimaBackendSnapshot {
        async let dockerLoad = loadDockerSnapshot(profile: profile, status: status)
        async let kubernetesLoad = status.kubernetes.enabled
            ? kubernetesService.loadSnapshot(context: status.kubernetes.context.nonEmpty)
            : ResourceLoadState<KubernetesResourceSnapshot>.idle

        let dockerState = await dockerLoad
        let kubernetesState = await kubernetesLoad
        let docker = dockerState.value
        let kubernetes = kubernetesState.value
        var issues = docker?.issues ?? []
        issues += kubernetes?.issues ?? []
        if case let .failed(issue, _) = dockerState {
            issues.append(issue)
        }
        if case let .failed(issue, _) = kubernetesState {
            issues.append(issue)
        }

        return ColimaBackendSnapshot(
            profile: profile,
            status: status,
            docker: docker,
            kubernetes: kubernetes,
            metrics: metricsCollector.metrics(profile: profile, docker: docker, kubernetes: kubernetes),
            issues: issues,
            collectedAt: Date()
        )
    }

    private func loadDockerSnapshot(profile: ColimaProfile, status: ColimaStatusDetail) async -> ResourceLoadState<DockerResourceSnapshot> {
        guard (status.runtime ?? profile.runtime) == .docker else {
            return .idle
        }
        return await dockerService.loadSnapshot(context: status.dockerContext.isEmpty ? profile.dockerContext : status.dockerContext)
    }
}
