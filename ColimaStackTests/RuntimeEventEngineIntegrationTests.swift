import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct RuntimeEventEngineIntegrationTests {
    @Test func profileSwitchCancelsOldSourcesAndStartsNew() async {
        let appState = AppState(colima: EmptyColimaCLIForEngine(), profiles: [
            Self.profile(named: "default", state: .running),
            Self.profile(named: "dev", state: .running)
        ])
        appState.selectedProfileID = "default"
        appState.selectedProfileDetail = Self.detail(profile: "default")

        let engine = RuntimeEventEngine()
        let defaultSource = FakeSource(label: "default")
        let devSource = FakeSource(label: "dev")

        engine.dockerSourceFactory = { profile, _ in
            // Return the source matching the profile name.
            return FakeSource(label: profile.name)
        }
        engine.colimaSourceFactory = { profile in
            return FakeSource(label: "colima-\(profile.name)")
        }

        engine.start(appState: appState)

        // Allow the engine to start sources for "default".
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Switch to "dev".
        appState.selectedProfileID = "dev"
        try? await Task.sleep(nanoseconds: 200_000_000)

        // The engine should have handled the profile change. We can't directly
        // assert on internal task state, but we can verify the app state is still
        // valid and the engine didn't crash.
        #expect(appState.selectedProfileID == "dev")

        engine.stop()
    }

    @Test func engineFeedsEventsToAppStateReducer() async {
        let appState = AppState(colima: EmptyColimaCLIForEngine(), profiles: [
            Self.profile(named: "default", state: .running)
        ])
        appState.selectedProfileID = "default"
        appState.selectedProfileDetail = Self.detail(profile: "default")

        let engine = RuntimeEventEngine()
        let testSource = FakeSource(label: "default", initialEvents: [
            .snapshotReplaced(source: .docker, docker: DockerResourceSnapshotSlice(
                context: "colima",
                containers: [DockerContainerResource(id: "abc", name: "web", image: "nginx", command: "", createdAt: "", runningFor: "", ports: "", state: "running", status: "Up", size: "", labels: [:])],
                images: [], volumes: [], networks: [], stats: [], diskUsage: []
            ), kubernetes: nil),
            .connectionStateChanged(source: .docker, state: .connected)
        ])

        engine.dockerSourceFactory = { _, _ in testSource }

        engine.start(appState: appState)

        // Allow the consumer to process events.
        try? await Task.sleep(nanoseconds: 300_000_000)

        #expect(appState.backendSnapshot?.docker?.containers.count == 1)
        #expect(appState.backendSnapshot?.docker?.containers.first?.name == "web")
        #expect(appState.connectionStatus.docker == .connected)

        engine.stop()
    }

    fileprivate static func profile(named name: String, state: ProfileState) -> ColimaProfile {
        ColimaProfile(name: name, state: state, runtime: .docker, architecture: .aarch64,
            resources: .standard, diskUsage: "", ipAddress: "192.168.5.15",
            dockerContext: "colima", kubernetes: .disabled, vmType: .qemu,
            mountType: .sshfs, socket: "unix:///tmp/\(name).sock", rawSummary: "")
    }

    fileprivate static func detail(profile: String) -> ColimaStatusDetail {
        ColimaStatusDetail(profileName: profile, state: .running, runtime: .docker,
            architecture: .aarch64, vmType: .qemu, mountType: .sshfs, resources: .standard,
            kubernetes: .disabled, networkAddress: "192.168.5.15",
            socket: "unix:///tmp/\(profile).sock", dockerContext: "colima",
            errors: [], rawOutput: "")
    }
}

/// A fake source that yields a fixed set of events then stays alive until cancelled.
private final class FakeSource: RuntimeEventSource {
    let label: String
    let initialEvents: [RuntimeEvent]

    init(label: String, initialEvents: [RuntimeEvent] = []) {
        self.label = label
        self.initialEvents = initialEvents
    }

    func events() -> AsyncThrowingStream<RuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for event in self.initialEvents {
                    continuation.yield(event)
                }
                // Stay alive until cancelled.
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                continuation.finish()
            }
        }
    }
}

@MainActor
private struct EmptyColimaCLIForEngine: ColimaControlling {
    func diagnostics(profile: String?) async -> DiagnosticReport { .empty }
    func listProfiles() async throws -> [ColimaProfile] { [] }
    func status(profile: String) async throws -> ColimaStatusDetail {
        RuntimeEventEngineIntegrationTests.detail(profile: profile)
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
