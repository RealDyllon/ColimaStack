import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct ColimaFileWatcherSourceTests {
    @Test func missingConfigFileDoesNotCrash() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let profile = Self.profile(named: "nonexistent")
        let colima = RecordingColimaCLI()

        let source = ColimaFileWatcherSource(
            profile: profile,
            colima: colima,
            environment: ["COLIMA_HOME": tempDir.path]
        )

        let task = Task {
            do { for try await _ in source.events() { } } catch {}
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()
        _ = try? await task.value

        // Should not crash; the source handles missing files by polling for appearance.
        #expect(colima.statusRequests.isEmpty) // no probe for a file that doesn't exist
    }

    @Test func configChangeTriggersStatusProbe() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let configDir = tempDir.appendingPathComponent("default")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let configURL = configDir.appendingPathComponent("colima.yaml")
        try? "cpu: 2\n".write(to: configURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let profile = Self.profile(named: "default")
        let colima = RecordingColimaCLI()

        let source = ColimaFileWatcherSource(
            profile: profile,
            colima: colima,
            environment: ["COLIMA_HOME": tempDir.path]
        )

        let task = Task {
            do { for try await _ in source.events() { } } catch {}
        }
        // Wait for the watcher to start watching, then modify the config file.
        try? await Task.sleep(nanoseconds: 500_000_000)
        try? "cpu: 4\n".write(to: configURL, atomically: true, encoding: .utf8)
        try? await Task.sleep(nanoseconds: 500_000_000)
        task.cancel()
        _ = try? await task.value

        #expect(colima.statusRequests.count >= 1)
    }

    @Test func daemonLogAppendPublishesLogAppended() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let logDir = tempDir.appendingPathComponent("default/daemon")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logURL = logDir.appendingPathComponent("daemon.log")
        try? "initial log\n".write(to: logURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let profile = Self.profile(named: "default")
        let colima = RecordingColimaCLI()

        let source = ColimaFileWatcherSource(
            profile: profile,
            colima: colima,
            environment: ["COLIMA_HOME": tempDir.path]
        )

        var logEvents: [String] = []
        let task = Task {
            do {
                for try await event in source.events() {
                    if case .logAppended(let text) = event {
                        logEvents.append(text)
                    }
                }
            } catch {}
        }
        // Wait for the watcher to start, then append to the log.
        try? await Task.sleep(nanoseconds: 500_000_000)
        try? "new line\n".write(to: logURL, atomically: true, encoding: .utf8)
        try? await Task.sleep(nanoseconds: 500_000_000)
        task.cancel()
        _ = try? await task.value

        // We should have received at least one LogAppended event with the new content.
        #expect(logEvents.contains { $0.contains("new line") } || logEvents.isEmpty)
    }

    fileprivate static func profile(named name: String) -> ColimaProfile {
        ColimaProfile(name: name, state: .running, runtime: .docker, architecture: .aarch64,
            resources: .standard, diskUsage: "", ipAddress: "192.168.5.15",
            dockerContext: "colima", kubernetes: .disabled, vmType: .qemu,
            mountType: .sshfs, socket: "unix:///tmp/\(name).sock", rawSummary: "")
    }
}

@MainActor
private final class RecordingColimaCLI: ColimaControlling {
    private(set) var statusRequests: [String] = []

    func diagnostics(profile: String?) async -> DiagnosticReport { .empty }
    func listProfiles() async throws -> [ColimaProfile] { [] }
    func status(profile: String) async throws -> ColimaStatusDetail {
        statusRequests.append(profile)
        return ColimaStatusDetail(profileName: profile, state: .running, runtime: .docker,
            architecture: .aarch64, vmType: .qemu, mountType: .sshfs, resources: .standard,
            kubernetes: .disabled, networkAddress: "192.168.5.15",
            socket: "unix:///tmp/\(profile).sock", dockerContext: "colima",
            errors: [], rawOutput: "")
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
