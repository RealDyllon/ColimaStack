import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct RuntimeEventReducerTests {
    @Test func snapshotReplacedReplacesDockerSlice() {
        let state = AppState(colima: EmptyColimaCLI(), profiles: [Self.profile(named: "default")])
        state.selectedProfileID = "default"
        state.selectedProfileDetail = Self.detail(profile: "default")

        let slice = DockerResourceSnapshotSlice(
            context: "colima",
            containers: [Self.container(id: "abc", name: "web")],
            images: [],
            volumes: [],
            networks: [],
            stats: [],
            diskUsage: []
        )
        state.reduce(.snapshotReplaced(source: .docker, docker: slice, kubernetes: nil))

        #expect(state.backendSnapshot?.docker?.containers.count == 1)
        #expect(state.backendSnapshot?.docker?.containers.first?.name == "web")
    }

    @Test func dockerContainerModifiedUpdatesOnlyThatContainer() {
        let state = AppState(colima: EmptyColimaCLI(), profiles: [Self.profile(named: "default")])
        state.selectedProfileID = "default"
        state.selectedProfileDetail = Self.detail(profile: "default")

        let slice = DockerResourceSnapshotSlice(
            context: "colima",
            containers: [Self.container(id: "abc", name: "web"), Self.container(id: "def", name: "db")],
            images: [],
            volumes: [],
            networks: [],
            stats: [],
            diskUsage: []
        )
        state.reduce(.snapshotReplaced(source: .docker, docker: slice, kubernetes: nil))

        let updated = Self.container(id: "abc", name: "web-v2")
        state.reduce(.dockerItem(kind: .container, change: .modified, id: "abc", record: .container(updated)))

        #expect(state.backendSnapshot?.docker?.containers.count == 2)
        #expect(state.backendSnapshot?.docker?.containers.first(where: { $0.id == "abc" })?.name == "web-v2")
        #expect(state.backendSnapshot?.docker?.containers.first(where: { $0.id == "def" })?.name == "db")
    }

    @Test func dockerContainerRemovedRemovesOnlyThatContainer() {
        let state = AppState(colima: EmptyColimaCLI(), profiles: [Self.profile(named: "default")])
        state.selectedProfileID = "default"
        state.selectedProfileDetail = Self.detail(profile: "default")

        let slice = DockerResourceSnapshotSlice(
            context: "colima",
            containers: [Self.container(id: "abc", name: "web"), Self.container(id: "def", name: "db")],
            images: [],
            volumes: [],
            networks: [],
            stats: [],
            diskUsage: []
        )
        state.reduce(.snapshotReplaced(source: .docker, docker: slice, kubernetes: nil))

        state.reduce(.dockerItem(kind: .container, change: .removed, id: "abc", record: nil))

        #expect(state.backendSnapshot?.docker?.containers.count == 1)
        #expect(state.backendSnapshot?.docker?.containers.first?.id == "def")
    }

    @Test func kubernetesPodRemovedRemovesOnlyThatPod() {
        let state = AppState(colima: EmptyColimaCLI(), profiles: [Self.profile(named: "default")])
        state.selectedProfileID = "default"
        state.selectedProfileDetail = Self.detail(profile: "default")

        let k8sSlice = KubernetesResourceSnapshotSlice(
            context: "colima",
            nodes: [],
            namespaces: [],
            pods: [Self.pod(name: "api", namespace: "default"), Self.pod(name: "worker", namespace: "default")],
            services: [],
            deployments: [],
            metrics: []
        )
        state.reduce(.snapshotReplaced(source: .kubernetes, docker: nil, kubernetes: k8sSlice))

        state.reduce(.kubernetesItem(kind: .pod, change: .removed, id: "default/api", record: nil))

        #expect(state.backendSnapshot?.kubernetes?.pods.count == 1)
        #expect(state.backendSnapshot?.kubernetes?.pods.first?.metadata.name == "worker")
    }

    @Test func logAppendedAppendsWithReReading() {
        let state = AppState(colima: EmptyColimaCLI(), profiles: [Self.profile(named: "default")])
        state.selectedProfileID = "default"
        state.logs = "line1\n"

        state.reduce(.logAppended("line2\nline3\n"))

        #expect(state.logs == "line1\nline2\nline3\n")
    }

    @Test func colimaStatusUpdatedUpdatesProfileState() {
        let state = AppState(colima: EmptyColimaCLI(), profiles: [Self.profile(named: "default")])
        state.selectedProfileID = "default"

        let updatedDetail = ColimaStatusDetail(
            profileName: "default",
            state: .stopped,
            runtime: .docker,
            architecture: nil,
            vmType: nil,
            mountType: nil,
            resources: nil,
            kubernetes: .disabled,
            networkAddress: "",
            socket: "",
            dockerContext: "colima",
            errors: [],
            rawOutput: ""
        )
        state.reduce(.colimaStatusUpdated(updatedDetail))

        #expect(state.selectedProfileDetail?.state == .stopped)
        #expect(state.profiles.first?.state == .stopped)
    }

    @Test func statsSampleAppendsToMonitorHistory() {
        let state = AppState(colima: EmptyColimaCLI(), profiles: [Self.profile(named: "default")])
        state.selectedProfileID = "default"

        let sample = RuntimeUsageSample(
            profileID: "default",
            profileName: "default",
            collectedAt: Date(),
            cpuPercent: 42,
            memoryUsedBytes: 1_000_000_000,
            memoryLimitBytes: 4_000_000_000,
            diskUsedBytes: 2_000_000_000,
            diskLimitBytes: 10_000_000_000,
            networkReceiveBytes: 100,
            networkTransmitBytes: 200,
            blockReadBytes: 300,
            blockWriteBytes: 400,
            runningContainerCount: 3
        )
        state.reduce(.statsSample(sample))

        #expect(state.monitorHistory.count == 1)
        #expect(state.monitorHistory.first?.cpuPercent == 42)
    }

    // MARK: - Helpers

    fileprivate static func profile(named name: String) -> ColimaProfile {
        ColimaProfile(
            name: name,
            state: .running,
            runtime: .docker,
            architecture: .aarch64,
            resources: .standard,
            diskUsage: "",
            ipAddress: "192.168.5.15",
            dockerContext: "colima",
            kubernetes: .disabled,
            vmType: .qemu,
            mountType: .sshfs,
            socket: "unix:///tmp/\(name).sock",
            rawSummary: ""
        )
    }

    fileprivate static func detail(profile: String) -> ColimaStatusDetail {
        ColimaStatusDetail(
            profileName: profile,
            state: .running,
            runtime: .docker,
            architecture: .aarch64,
            vmType: .qemu,
            mountType: .sshfs,
            resources: .standard,
            kubernetes: .disabled,
            networkAddress: "192.168.5.15",
            socket: "unix:///tmp/\(profile).sock",
            dockerContext: "colima",
            errors: [],
            rawOutput: ""
        )
    }

    fileprivate static func container(id: String, name: String) -> DockerContainerResource {
        DockerContainerResource(
            id: id,
            name: name,
            image: "nginx",
            command: "",
            createdAt: "",
            runningFor: "",
            ports: "",
            state: "running",
            status: "Up",
            size: "",
            labels: [:]
        )
    }

    fileprivate static func pod(name: String, namespace: String) -> KubernetesPodResource {
        KubernetesPodResource(
            metadata: KubernetesObjectMetadata(
                name: name,
                namespace: namespace,
                uid: "default/\(name)",
                labels: [:],
                creationTimestamp: nil
            ),
            nodeName: "node-1",
            phase: "Running",
            podIP: "10.0.0.1",
            hostIP: "192.168.5.15",
            containers: []
        )
    }
}

@MainActor
private struct EmptyColimaCLI: ColimaControlling {
    func diagnostics(profile: String?) async -> DiagnosticReport { .empty }
    func listProfiles() async throws -> [ColimaProfile] { [] }
    func status(profile: String) async throws -> ColimaStatusDetail {
        RuntimeEventReducerTests.detail(profile: profile)
    }
    func logs(profile: String) async throws -> String { "" }
    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "start"]), exitCode: 0, stdout: "", stderr: "")
    }
    func stop(profile: String) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "stop"]), exitCode: 0, stdout: "", stderr: "")
    }
    func restart(profile: String) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "restart"]), exitCode: 0, stdout: "", stderr: "")
    }
    func delete(profile: String) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "delete"]), exitCode: 0, stdout: "", stderr: "")
    }
    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "kubernetes"]), exitCode: 0, stdout: "", stderr: "")
    }
    func update(profile: String) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "update"]), exitCode: 0, stdout: "", stderr: "")
    }
    func template() async throws -> String { "" }
    func configuration(profile: String) async throws -> ProfileConfiguration? { nil }
}
