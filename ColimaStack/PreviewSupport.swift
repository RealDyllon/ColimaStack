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
        let state = AppState(colima: MockColimaCLI(), profiles: mockProfiles)
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
        let snapshot = ColimaBackendSnapshot(
            profile: mockProfiles[0],
            status: state.selectedProfileDetail!,
            docker: DockerResourceSnapshot(
                context: "colima",
                collectedAt: now,
                containers: [
                    DockerContainerResource(id: "api", name: "api", image: "example/api", command: "", createdAt: "", runningFor: "2 hours", ports: "8080/tcp", state: "running", status: "Up 2 hours", size: "", labels: [:])
                ],
                images: [],
                volumes: [],
                networks: [],
                stats: [
                    DockerStatsResource(id: "api", name: "api", cpuPercent: "18.4%", memoryUsage: "1.4GiB / 12GiB", memoryPercent: "11.6%", networkIO: "120MB / 48MB", blockIO: "2.1GB / 320MB", pids: "34")
                ],
                diskUsage: [
                    DockerDiskUsageResource(type: "Images", totalCount: "8", activeCount: "3", size: "8.2GB", reclaimable: "1.1GB (13%)"),
                    DockerDiskUsageResource(type: "Volumes", totalCount: "4", activeCount: "2", size: "1.7GB", reclaimable: "200MB (12%)")
                ],
                issues: [],
                commandRuns: []
            ),
            kubernetes: nil,
            metrics: [],
            issues: [],
            collectedAt: now
        )
        state.backendSnapshot = snapshot
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
        state.logs = "INFO starting colima\nINFO docker runtime is ready\nINFO kubernetes is ready"
        return state
    }

    static let mockProfiles = [
        ColimaProfile(name: "default", state: .running, runtime: .docker, architecture: .aarch64, resources: ResourceAllocation(cpu: 6, memoryGiB: 12, diskGiB: 120), diskUsage: "120 GiB", ipAddress: "192.168.106.2", dockerContext: "colima", kubernetes: KubernetesConfig(enabled: true, version: "v1.30.4+k3s1", context: "colima"), vmType: .vz, mountType: .virtiofs, socket: dockerSocket, rawSummary: ""),
        ColimaProfile(name: "k8s-lab", state: .stopped, runtime: .containerd, architecture: .aarch64, resources: ResourceAllocation(cpu: 4, memoryGiB: 8, diskGiB: 80), diskUsage: "80 GiB", ipAddress: "", dockerContext: "colima-k8s-lab", kubernetes: KubernetesConfig(enabled: true, version: "v1.29.7+k3s1", context: "colima-k8s-lab"), vmType: .qemu, mountType: .sshfs, socket: "", rawSummary: "")
    ]
}

struct MockColimaCLI: ColimaControlling {
    func diagnostics() async -> DiagnosticReport { PreviewSupport.mockDiagnostics }
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
