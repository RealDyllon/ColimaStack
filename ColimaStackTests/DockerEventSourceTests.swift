import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct DockerEventSourceTests {
    @Test func nonDockerRuntimePublishesDisconnectedAndFinishes() async {
        var profile = Self.profile(named: "build")
        profile.runtime = .containerd
        var status = Self.detail(profile: "build")
        status.runtime = .containerd

        let source = DockerEventSource(
            profile: profile,
            status: status,
            dockerProvider: FailingDockerProvider(),
            streamingRunner: LiveStreamingProcessRunner(),
            toolLocator: FakeToolLocator(urls: ["docker": URL(fileURLWithPath: "/usr/bin/docker")])
        )

        var events: [RuntimeEvent] = []
        do {
            for try await event in source.events() {
                events.append(event)
            }
        } catch {}

        #expect(events.contains { if case .connectionStateChanged(.docker, .disconnected) = $0 { return true }; return false })
    }

    @Test func dockerNotInstalledPublishesFailedAndFinishes() async {
        let profile = Self.profile(named: "default")
        let status = Self.detail(profile: "default")

        let source = DockerEventSource(
            profile: profile,
            status: status,
            dockerProvider: FailingDockerProvider(),
            streamingRunner: LiveStreamingProcessRunner(),
            toolLocator: FakeToolLocator(urls: [:])
        )

        var events: [RuntimeEvent] = []
        do {
            for try await event in source.events() {
                events.append(event)
            }
        } catch {}

        #expect(events.contains { if case .connectionStateChanged(.docker, .failed(_)) = $0 { return true }; return false })
    }

    @Test func bootstrapPublishesSnapshotReplacedAndConnected() async {
        let profile = Self.profile(named: "default")
        let status = Self.detail(profile: "default")

        let source = DockerEventSource(
            profile: profile,
            status: status,
            dockerProvider: StubDockerProvider(containers: [DockerContainerResource(id: "abc", name: "web", image: "nginx", command: "", createdAt: "", runningFor: "", ports: "", state: "running", status: "Up", size: "", labels: [:])]),
            streamingRunner: FakeStreamingRunner(events: []),
            toolLocator: FakeToolLocator(urls: ["docker": URL(fileURLWithPath: "/usr/bin/docker")])
        )

        var events: [RuntimeEvent] = []
        let collectorTask = Task {
            do {
                for try await event in source.events() {
                    events.append(event)
                    if case .connectionStateChanged(.docker, .connected) = event {
                        break
                    }
                }
            } catch {}
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        collectorTask.cancel()
        _ = try? await collectorTask.value

        #expect(events.contains { if case .snapshotReplaced(.docker, _, _) = $0 { return true }; return false })
        #expect(events.contains { if case .connectionStateChanged(.docker, .connected) = $0 { return true }; return false })
    }

    // MARK: - Helpers

    fileprivate static func profile(named name: String) -> ColimaProfile {
        ColimaProfile(
            name: name, state: .running, runtime: .docker, architecture: .aarch64,
            resources: .standard, diskUsage: "", ipAddress: "192.168.5.15",
            dockerContext: "colima", kubernetes: .disabled, vmType: .qemu,
            mountType: .sshfs, socket: "unix:///tmp/\(name).sock", rawSummary: ""
        )
    }

    fileprivate static func detail(profile: String) -> ColimaStatusDetail {
        ColimaStatusDetail(
            profileName: profile, state: .running, runtime: .docker, architecture: .aarch64,
            vmType: .qemu, mountType: .sshfs, resources: .standard, kubernetes: .disabled,
            networkAddress: "192.168.5.15", socket: "unix:///tmp/\(profile).sock",
            dockerContext: "colima", errors: [], rawOutput: ""
        )
    }
}

// MARK: - Fakes

@MainActor
private final class FailingDockerProvider: DockerResourceProviding {
    func loadSnapshot(context: String?) async -> ResourceLoadState<DockerResourceSnapshot> {
        .failed(BackendIssue(severity: .error, source: .docker, title: "fail", message: "no docker"), lastValue: nil)
    }
    func snapshot(context: String?) async throws -> DockerResourceSnapshot {
        throw DockerTestError(message: "no docker")
    }
}

@MainActor
private final class StubDockerProvider: DockerResourceProviding {
    let containers: [DockerContainerResource]
    init(containers: [DockerContainerResource]) { self.containers = containers }
    func loadSnapshot(context: String?) async -> ResourceLoadState<DockerResourceSnapshot> {
        do {
            return .loaded(try await snapshot(context: context), updatedAt: Date())
        } catch {
            return .failed(BackendIssue(severity: .error, source: .docker, title: "fail", message: error.localizedDescription), lastValue: nil)
        }
    }
    func snapshot(context: String?) async throws -> DockerResourceSnapshot {
        DockerResourceSnapshot(
            context: context ?? "colima", collectedAt: Date(),
            containers: containers, images: [], volumes: [], networks: [],
            stats: [], diskUsage: [], issues: [], commandRuns: []
        )
    }
}

/// A fake streaming runner that yields a fixed set of events then finishes.
private final class FakeStreamingRunner: StreamingProcessRunning {
    let events: [StreamingProcessEvent]
    init(events: [StreamingProcessEvent]) { self.events = events }

    func run(_ request: ProcessRequest, cancellation: ProcessCancellation?) -> AsyncThrowingStream<StreamingProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for event in self.events {
                    continuation.yield(event)
                }
                // Simulate the process running indefinitely (so the source stays in the
                // events loop). The test cancels the collector after checking the bootstrap.
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                continuation.finish()
            }
        }
    }
}

private struct DockerTestError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
