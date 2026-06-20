import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct KubernetesWatchSourceTests {
    @Test func kubernetesDisabledPublishesDisconnectedAndFinishes() async {
        var profile = Self.profile(named: "default")
        profile.kubernetes = .disabled
        let status = Self.detail(profile: "default")

        let source = KubernetesWatchSource(
            profile: profile,
            status: status,
            kubernetesProvider: FailingKubernetesProvider(),
            streamingRunner: LiveStreamingProcessRunner(),
            toolLocator: FakeToolLocator(urls: ["kubectl": URL(fileURLWithPath: "/usr/bin/kubectl")])
        )

        var events: [RuntimeEvent] = []
        do { for try await event in source.events() { events.append(event) } } catch {}

        #expect(events.contains { if case .connectionStateChanged(.kubernetes, .disconnected) = $0 { return true }; return false })
    }

    @Test func kubectlNotInstalledPublishesFailedAndFinishes() async {
        let profile = Self.profile(named: "default")
        let status = Self.detail(profile: "default")

        let source = KubernetesWatchSource(
            profile: profile,
            status: status,
            kubernetesProvider: FailingKubernetesProvider(),
            streamingRunner: LiveStreamingProcessRunner(),
            toolLocator: FakeToolLocator(urls: [:])
        )

        var events: [RuntimeEvent] = []
        do { for try await event in source.events() { events.append(event) } } catch {}

        #expect(events.contains { if case .connectionStateChanged(.kubernetes, .failed(_)) = $0 { return true }; return false })
    }

    @Test func bootstrapPublishesSnapshotReplacedAndConnected() async {
        var profile = Self.profile(named: "default")
        profile.kubernetes = KubernetesConfig(enabled: true, version: "v1.30.4+k3s1", context: "colima")
        var status = Self.detail(profile: "default")
        status.kubernetes = KubernetesConfig(enabled: true, version: "v1.30.4+k3s1", context: "colima")

        let source = KubernetesWatchSource(
            profile: profile,
            status: status,
            kubernetesProvider: StubKubernetesProvider(),
            streamingRunner: FakeK8sStreamingRunner(),
            toolLocator: FakeToolLocator(urls: ["kubectl": URL(fileURLWithPath: "/usr/bin/kubectl")])
        )

        var events: [RuntimeEvent] = []
        let task = Task {
            do { for try await event in source.events() {
                events.append(event)
                if case .connectionStateChanged(.kubernetes, .connected) = event { break }
            } } catch {}
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()
        _ = try? await task.value

        #expect(events.contains { if case .snapshotReplaced(.kubernetes, _, _) = $0 { return true }; return false })
        #expect(events.contains { if case .connectionStateChanged(.kubernetes, .connected) = $0 { return true }; return false })
    }

    fileprivate static func profile(named name: String) -> ColimaProfile {
        ColimaProfile(name: name, state: .running, runtime: .docker, architecture: .aarch64,
            resources: .standard, diskUsage: "", ipAddress: "192.168.5.15",
            dockerContext: "colima", kubernetes: .disabled, vmType: .qemu,
            mountType: .sshfs, socket: "unix:///tmp/\(name).sock", rawSummary: "")
    }

    fileprivate static func detail(profile: String) -> ColimaStatusDetail {
        ColimaStatusDetail(profileName: profile, state: .running, runtime: .docker, architecture: .aarch64,
            vmType: .qemu, mountType: .sshfs, resources: .standard, kubernetes: .disabled,
            networkAddress: "192.168.5.15", socket: "unix:///tmp/\(profile).sock",
            dockerContext: "colima", errors: [], rawOutput: "")
    }
}

@MainActor
private final class FailingKubernetesProvider: KubernetesResourceProviding {
    func loadSnapshot(context: String?) async -> ResourceLoadState<KubernetesResourceSnapshot> {
        .failed(BackendIssue(severity: .error, source: .kubernetes, title: "fail", message: "no k8s"), lastValue: nil)
    }
    func snapshot(context: String?) async throws -> KubernetesResourceSnapshot {
        throw TestK8sError(message: "no k8s")
    }
}

@MainActor
private final class StubKubernetesProvider: KubernetesResourceProviding {
    func loadSnapshot(context: String?) async -> ResourceLoadState<KubernetesResourceSnapshot> {
        do {
            return .loaded(try await snapshot(context: context), updatedAt: Date())
        } catch {
            return .failed(BackendIssue(severity: .error, source: .kubernetes, title: "fail", message: error.localizedDescription), lastValue: nil)
        }
    }
    func snapshot(context: String?) async throws -> KubernetesResourceSnapshot {
        KubernetesResourceSnapshot(context: context ?? "colima", collectedAt: Date(),
            nodes: [], namespaces: [], pods: [], services: [], deployments: [],
            metrics: [], issues: [], commandRuns: [])
    }
}

private final class FakeK8sStreamingRunner: StreamingProcessRunning {
    func run(_ request: ProcessRequest, cancellation: ProcessCancellation?) -> AsyncThrowingStream<StreamingProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Simulate a long-running watch; the test cancels after bootstrap.
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                continuation.finish()
            }
        }
    }
}

private struct TestK8sError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
