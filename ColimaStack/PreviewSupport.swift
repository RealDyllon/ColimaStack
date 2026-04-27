import Foundation

enum PreviewSupport {
    fileprivate static var dockerSocket: String {
        "unix://\(NSHomeDirectory())/.colima/default/docker.sock"
    }

    static let mockDiagnostics = DiagnosticReport(
        tools: [
            ToolCheck(id: "colima", availability: .available(path: "/opt/homebrew/bin/colima", version: "colima version 0.8.4")),
            ToolCheck(id: "docker", availability: .available(path: "/usr/local/bin/docker", version: "28.0.0")),
            ToolCheck(id: "kubectl", availability: .available(path: "/opt/homebrew/bin/kubectl", version: "Client Version: v1.31.0")),
            ToolCheck(id: "limactl", availability: .available(path: "/opt/homebrew/bin/limactl", version: "limactl version 1.0.0"))
        ],
        colima: ColimaRuntimeStatus(profileName: "default", state: .running, output: "colima is running", error: ""),
        docker: DockerStatus(available: true, context: "colima", version: "28.0.0", error: ""),
        messages: []
    )

    @MainActor
    static var appState: AppState {
        let state = AppState(colima: MockColimaCLI(), profiles: mockProfiles, backend: MockBackendSnapshotService())
        state.diagnostics = mockDiagnostics
        state.selectedProfileID = "default"
        state.selectedProfileDetail = ColimaStatusDetail(
            profileName: "default",
            state: .running,
            runtime: .docker,
            architecture: .aarch64,
            vmType: .vz,
            mountType: .virtiofs,
            resources: ResourceAllocation(cpu: 6, memoryGiB: 12, diskGiB: 120),
            kubernetes: KubernetesConfig(enabled: true, version: "v1.30.4+k3s1", context: "colima"),
            networkAddress: "192.168.106.2",
            socket: dockerSocket,
            dockerContext: "colima",
            errors: [],
            rawOutput: ""
        )
        let now = Date()
        state.backendSnapshot = mockBackendSnapshot(profile: mockProfiles[0], status: state.selectedProfileDetail!, collectedAt: now)
        state.monitorHistory = stride(from: 8, through: 0, by: -1).map { offset in
            RuntimeUsageSample(
                profileID: "default",
                profileName: "default",
                collectedAt: now.addingTimeInterval(TimeInterval(-offset * 10)),
                cpuPercent: Double(10 + offset * 2),
                memoryUsedBytes: Double(900 + offset * 75) * 1_048_576,
                memoryLimitBytes: 12 * 1_073_741_824,
                diskUsedBytes: Double(9_000 + offset * 120) * 1_048_576,
                diskLimitBytes: 120 * 1_073_741_824,
                networkReceiveBytes: Double(80_000_000 + offset * 6_000_000),
                networkTransmitBytes: Double(30_000_000 + offset * 3_000_000),
                blockReadBytes: Double(1_000_000_000 + offset * 40_000_000),
                blockWriteBytes: Double(240_000_000 + offset * 12_000_000),
                runningContainerCount: 1
            )
        }
        state.commandLog = mockCommandLog(collectedAt: now)
        state.logs = "INFO starting colima\nINFO docker runtime is ready\nINFO kubernetes is ready"
        return state
    }

    static let mockProfiles = [
        ColimaProfile(
            name: "default",
            state: .running,
            runtime: .docker,
            architecture: .aarch64,
            resources: ResourceAllocation(cpu: 6, memoryGiB: 12, diskGiB: 120),
            diskUsage: "120 GiB",
            ipAddress: "192.168.106.2",
            dockerContext: "colima",
            kubernetes: KubernetesConfig(enabled: true, version: "v1.30.4+k3s1", context: "colima"),
            vmType: .vz,
            mountType: .virtiofs,
            socket: dockerSocket,
            rawSummary: "",
            mounts: [
                ColimaMount(location: "\(NSHomeDirectory())/Developer", mountPoint: "/Users/dev/Developer", writable: true),
                ColimaMount(location: "\(NSHomeDirectory())/.cache", mountPoint: "/var/cache/dev", writable: false)
            ]
        ),
        ColimaProfile(
            name: "k8s-lab",
            state: .stopped,
            runtime: .containerd,
            architecture: .aarch64,
            resources: ResourceAllocation(cpu: 4, memoryGiB: 8, diskGiB: 80),
            diskUsage: "80 GiB",
            ipAddress: "",
            dockerContext: "colima-k8s-lab",
            kubernetes: KubernetesConfig(enabled: true, version: "v1.29.7+k3s1", context: "colima-k8s-lab"),
            vmType: .qemu,
            mountType: .sshfs,
            socket: "",
            rawSummary: ""
        )
    ]

    static func mockBackendSnapshot(
        profile: ColimaProfile,
        status: ColimaStatusDetail,
        collectedAt: Date = Date()
    ) -> ColimaBackendSnapshot {
        let docker = DockerResourceSnapshot(
            context: status.dockerContext.nonEmpty ?? "colima",
            collectedAt: collectedAt,
            containers: [
                DockerContainerResource(id: "api-01", name: "orders-api", image: "ghcr.io/example/orders-api:1.8.0", command: "bundle exec puma", createdAt: "2026-04-22 09:14", runningFor: "2 hours", ports: "0.0.0.0:8080->8080/tcp", state: "running", status: "Up 2 hours", size: "92MB", labels: ["tier": "backend"]),
                DockerContainerResource(id: "web-01", name: "control-web", image: "ghcr.io/example/control-web:4.2.1", command: "pnpm start", createdAt: "2026-04-22 09:15", runningFor: "2 hours", ports: "0.0.0.0:3000->3000/tcp", state: "running", status: "Up 2 hours", size: "116MB", labels: ["tier": "frontend"]),
                DockerContainerResource(id: "db-01", name: "postgres", image: "postgres:16-alpine", command: "postgres", createdAt: "2026-04-22 09:12", runningFor: "3 hours", ports: "5432/tcp", state: "running", status: "Up 3 hours", size: "412MB", labels: ["tier": "data"]),
                DockerContainerResource(id: "jobs-01", name: "worker", image: "ghcr.io/example/orders-worker:1.8.0", command: "sidekiq", createdAt: "2026-04-22 09:17", runningFor: "38 minutes", ports: "", state: "running", status: "Up 38 minutes", size: "88MB", labels: ["tier": "jobs"])
            ],
            images: [
                DockerImageResource(id: "sha256:8a7d", repository: "ghcr.io/example/orders-api", tag: "1.8.0", digest: "sha256:8a7dbeef", createdAt: "2026-04-20", createdSince: "6 days ago", size: "291MB"),
                DockerImageResource(id: "sha256:94cf", repository: "ghcr.io/example/control-web", tag: "4.2.1", digest: "sha256:94cffee", createdAt: "2026-04-20", createdSince: "6 days ago", size: "184MB"),
                DockerImageResource(id: "sha256:16db", repository: "postgres", tag: "16-alpine", digest: "sha256:16db001", createdAt: "2026-04-18", createdSince: "8 days ago", size: "273MB"),
                DockerImageResource(id: "sha256:77aa", repository: "redis", tag: "7-alpine", digest: "sha256:77aa002", createdAt: "2026-04-18", createdSince: "8 days ago", size: "41MB")
            ],
            volumes: [
                DockerVolumeResource(name: "postgres-data", driver: "local", scope: "local", mountpoint: "/var/lib/docker/volumes/postgres-data/_data", labels: ["service": "postgres"]),
                DockerVolumeResource(name: "redis-cache", driver: "local", scope: "local", mountpoint: "/var/lib/docker/volumes/redis-cache/_data", labels: ["service": "redis"]),
                DockerVolumeResource(name: "uploads", driver: "local", scope: "local", mountpoint: "/var/lib/docker/volumes/uploads/_data", labels: ["service": "api"])
            ],
            networks: [
                DockerNetworkResource(id: "net-app", name: "app-backplane", driver: "bridge", scope: "local", internalOnly: false, ipv6Enabled: false),
                DockerNetworkResource(id: "net-observe", name: "observability", driver: "bridge", scope: "local", internalOnly: false, ipv6Enabled: true),
                DockerNetworkResource(id: "net-private", name: "private-data", driver: "bridge", scope: "local", internalOnly: true, ipv6Enabled: false)
            ],
            stats: [
                DockerStatsResource(id: "api-01", name: "orders-api", cpuPercent: "18.4%", memoryUsage: "1.4GiB / 12GiB", memoryPercent: "11.6%", networkIO: "120MB / 48MB", blockIO: "2.1GB / 320MB", pids: "34"),
                DockerStatsResource(id: "web-01", name: "control-web", cpuPercent: "8.2%", memoryUsage: "740MiB / 12GiB", memoryPercent: "6.0%", networkIO: "84MB / 66MB", blockIO: "900MB / 180MB", pids: "22"),
                DockerStatsResource(id: "db-01", name: "postgres", cpuPercent: "4.5%", memoryUsage: "1.1GiB / 12GiB", memoryPercent: "9.1%", networkIO: "41MB / 54MB", blockIO: "3.4GB / 1.2GB", pids: "18"),
                DockerStatsResource(id: "jobs-01", name: "worker", cpuPercent: "12.9%", memoryUsage: "680MiB / 12GiB", memoryPercent: "5.5%", networkIO: "32MB / 18MB", blockIO: "760MB / 240MB", pids: "16")
            ],
            diskUsage: [
                DockerDiskUsageResource(type: "Images", totalCount: "12", activeCount: "6", size: "8.2GB", reclaimable: "1.1GB (13%)"),
                DockerDiskUsageResource(type: "Containers", totalCount: "7", activeCount: "4", size: "820MB", reclaimable: "210MB (25%)"),
                DockerDiskUsageResource(type: "Volumes", totalCount: "5", activeCount: "3", size: "2.7GB", reclaimable: "340MB (12%)")
            ],
            issues: [],
            commandRuns: []
        )

        let kubernetes = KubernetesResourceSnapshot(
            context: status.kubernetes.context.nonEmpty ?? "colima",
            collectedAt: collectedAt,
            nodes: [
                KubernetesNodeResource(
                    metadata: KubernetesObjectMetadata(name: "colima-default", namespace: nil, uid: "node-colima-default", labels: ["node-role.kubernetes.io/control-plane": ""], creationTimestamp: collectedAt.addingTimeInterval(-12_000)),
                    roles: ["control-plane"],
                    phase: "Running",
                    kubeletVersion: "v1.30.4+k3s1",
                    internalIP: status.networkAddress.nonEmpty ?? "192.168.106.2",
                    allocatableCPU: "6",
                    allocatableMemory: "11336Mi",
                    conditions: ["Ready": "True"]
                )
            ],
            namespaces: [
                KubernetesNamespaceResource(metadata: KubernetesObjectMetadata(name: "default", namespace: nil, uid: "ns-default", labels: [:], creationTimestamp: collectedAt.addingTimeInterval(-12_000)), phase: "Active"),
                KubernetesNamespaceResource(metadata: KubernetesObjectMetadata(name: "observability", namespace: nil, uid: "ns-observability", labels: [:], creationTimestamp: collectedAt.addingTimeInterval(-8_000)), phase: "Active"),
                KubernetesNamespaceResource(metadata: KubernetesObjectMetadata(name: "kube-system", namespace: nil, uid: "ns-kube-system", labels: [:], creationTimestamp: collectedAt.addingTimeInterval(-12_000)), phase: "Active")
            ],
            pods: [
                KubernetesPodResource(
                    metadata: KubernetesObjectMetadata(name: "orders-api-7d59b8788c-42k9x", namespace: "default", uid: "pod-orders-api", labels: ["app": "orders-api"], creationTimestamp: collectedAt.addingTimeInterval(-6_000)),
                    nodeName: "colima-default",
                    phase: "Running",
                    podIP: "10.42.0.17",
                    hostIP: status.networkAddress.nonEmpty ?? "192.168.106.2",
                    containers: [KubernetesContainerStatusResource(name: "api", image: "ghcr.io/example/orders-api:1.8.0", ready: true, restartCount: 0, state: "running")]
                ),
                KubernetesPodResource(
                    metadata: KubernetesObjectMetadata(name: "worker-658c76b984-m9plk", namespace: "default", uid: "pod-worker", labels: ["app": "worker"], creationTimestamp: collectedAt.addingTimeInterval(-5_800)),
                    nodeName: "colima-default",
                    phase: "Running",
                    podIP: "10.42.0.18",
                    hostIP: status.networkAddress.nonEmpty ?? "192.168.106.2",
                    containers: [KubernetesContainerStatusResource(name: "worker", image: "ghcr.io/example/orders-worker:1.8.0", ready: true, restartCount: 1, state: "running")]
                ),
                KubernetesPodResource(
                    metadata: KubernetesObjectMetadata(name: "prometheus-server-74df7d94b9-tq6pn", namespace: "observability", uid: "pod-prometheus", labels: ["app": "prometheus"], creationTimestamp: collectedAt.addingTimeInterval(-4_200)),
                    nodeName: "colima-default",
                    phase: "Running",
                    podIP: "10.42.0.22",
                    hostIP: status.networkAddress.nonEmpty ?? "192.168.106.2",
                    containers: [KubernetesContainerStatusResource(name: "prometheus", image: "prom/prometheus:v2.53.0", ready: true, restartCount: 0, state: "running")]
                )
            ],
            services: [
                KubernetesServiceResource(metadata: KubernetesObjectMetadata(name: "orders-api", namespace: "default", uid: "svc-orders-api", labels: ["app": "orders-api"], creationTimestamp: collectedAt.addingTimeInterval(-5_900)), type: "ClusterIP", clusterIP: "10.43.71.120", externalIPs: [], ports: ["http/80/TCP"]),
                KubernetesServiceResource(metadata: KubernetesObjectMetadata(name: "control-web", namespace: "default", uid: "svc-control-web", labels: ["app": "control-web"], creationTimestamp: collectedAt.addingTimeInterval(-5_900)), type: "NodePort", clusterIP: "10.43.14.44", externalIPs: [], ports: ["http/3000/TCP"]),
                KubernetesServiceResource(metadata: KubernetesObjectMetadata(name: "prometheus", namespace: "observability", uid: "svc-prometheus", labels: ["app": "prometheus"], creationTimestamp: collectedAt.addingTimeInterval(-4_100)), type: "ClusterIP", clusterIP: "10.43.28.87", externalIPs: [], ports: ["web/9090/TCP"])
            ],
            deployments: [
                KubernetesDeploymentResource(metadata: KubernetesObjectMetadata(name: "orders-api", namespace: "default", uid: "deploy-orders-api", labels: ["app": "orders-api"], creationTimestamp: collectedAt.addingTimeInterval(-5_900)), desiredReplicas: 2, readyReplicas: 2, availableReplicas: 2, updatedReplicas: 2),
                KubernetesDeploymentResource(metadata: KubernetesObjectMetadata(name: "worker", namespace: "default", uid: "deploy-worker", labels: ["app": "worker"], creationTimestamp: collectedAt.addingTimeInterval(-5_800)), desiredReplicas: 1, readyReplicas: 1, availableReplicas: 1, updatedReplicas: 1),
                KubernetesDeploymentResource(metadata: KubernetesObjectMetadata(name: "prometheus-server", namespace: "observability", uid: "deploy-prometheus", labels: ["app": "prometheus"], creationTimestamp: collectedAt.addingTimeInterval(-4_100)), desiredReplicas: 1, readyReplicas: 1, availableReplicas: 1, updatedReplicas: 1)
            ],
            metrics: [
                KubernetesMetricResource(id: "node/colima-default", ownerKind: .node, namespace: nil, name: "colima-default", cpu: "410m", memory: "3580Mi"),
                KubernetesMetricResource(id: "pod/default/orders-api", ownerKind: .pod, namespace: "default", name: "orders-api", cpu: "120m", memory: "380Mi"),
                KubernetesMetricResource(id: "pod/default/worker", ownerKind: .pod, namespace: "default", name: "worker", cpu: "90m", memory: "260Mi")
            ],
            issues: [],
            commandRuns: []
        )

        return ColimaBackendSnapshot(
            profile: profile,
            status: status,
            docker: docker,
            kubernetes: kubernetes,
            metrics: BackendMetricsCollector().metrics(profile: profile, docker: docker, kubernetes: kubernetes),
            issues: docker.issues + kubernetes.issues,
            collectedAt: collectedAt
        )
    }

    private static func mockCommandLog(collectedAt: Date) -> [CommandLogEntry] {
        [
            CommandLogEntry(date: collectedAt.addingTimeInterval(-90), command: "Refresh backend snapshot", status: .succeeded, output: "Docker, Kubernetes, and runtime metrics refreshed."),
            CommandLogEntry(date: collectedAt.addingTimeInterval(-1_200), command: "Start default", status: .succeeded, output: "Colima profile default is running."),
            CommandLogEntry(date: collectedAt.addingTimeInterval(-3_600), command: "Enable Kubernetes", status: .succeeded, output: "Kubernetes context colima is ready.")
        ]
    }
}

struct MockColimaCLI: ColimaControlling {
    func diagnostics(profile: String?) async -> DiagnosticReport { PreviewSupport.mockDiagnostics }
    func listProfiles() async throws -> [ColimaProfile] { PreviewSupport.mockProfiles }
    func status(profile: String) async throws -> ColimaStatusDetail {
        ColimaStatusDetail(profileName: profile, state: .running, runtime: .docker, architecture: .aarch64, vmType: .vz, mountType: .virtiofs, resources: ResourceAllocation(cpu: 6, memoryGiB: 12, diskGiB: 120), kubernetes: KubernetesConfig(enabled: true, version: "v1.30.4+k3s1", context: "colima"), networkAddress: "192.168.106.2", socket: PreviewSupport.dockerSocket, dockerContext: "colima", errors: [], rawOutput: "")
    }
    func logs(profile: String) async throws -> String { "INFO \(profile) ready" }
    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult { mockResult("start") }
    func stop(profile: String) async throws -> ProcessResult { mockResult("stop") }
    func restart(profile: String) async throws -> ProcessResult { mockResult("restart") }
    func delete(profile: String) async throws -> ProcessResult { mockResult("delete") }
    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult { mockResult("kubernetes") }
    func update(profile: String) async throws -> ProcessResult { mockResult("update") }
    func template() async throws -> String { "cpu: 2\nmemory: 4" }
    func configuration(profile: String) async throws -> ProfileConfiguration? {
        var configuration = ProfileConfiguration.default
        configuration.name = profile
        configuration.resources = profile == "default" ? ResourceAllocation(cpu: 6, memoryGiB: 12, diskGiB: 120) : ResourceAllocation(cpu: 4, memoryGiB: 8, diskGiB: 80)
        configuration.runtime = profile == "default" ? .docker : .containerd
        configuration.vmType = profile == "default" ? .vz : .qemu
        configuration.mountType = profile == "default" ? .virtiofs : .sshfs
        configuration.kubernetes = KubernetesConfig(enabled: true, version: profile == "default" ? "v1.30.4+k3s1" : "v1.29.7+k3s1", context: profile == "default" ? "colima" : "colima-\(profile)")
        return configuration
    }

    private func mockResult(_ command: String) -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", command]), exitCode: 0, stdout: "ok", stderr: "")
    }
}

struct MockBackendSnapshotService: BackendSnapshotProviding {
    func snapshot(profile: ColimaProfile, status: ColimaStatusDetail) async -> ColimaBackendSnapshot {
        PreviewSupport.mockBackendSnapshot(profile: profile, status: status)
    }
}
