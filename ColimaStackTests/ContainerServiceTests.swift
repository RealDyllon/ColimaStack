//
//  ContainerServiceTests.swift
//  ColimaStackTests
//
//  Tests for the container-lifecycle capability: the ContainerService
//  records lifecycle commands in the activity log and bridges
//  notifications to its public methods.
//

import XCTest
import Combine
@testable import ColimaStack

@MainActor
final class ContainerServiceTests: XCTestCase {
    func testStartRecordsCommand() async {
        let state = makeAppState()
        let initialCount = state.commandLog.count
        await state.containerService.start(containerID: "abc123")
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertGreaterThan(state.commandLog.count, initialCount)
        let entry = state.commandLog.first { $0.command.contains("docker start") && $0.command.contains("abc123") }
        XCTAssertNotNil(entry, "expected a 'docker start abc123' entry in the command log")
    }

    func testStopRecordsCommand() async {
        let state = makeAppState()
        await state.containerService.stop(containerID: "xyz")
        try? await Task.sleep(nanoseconds: 50_000_000)
        let entry = state.commandLog.first { $0.command.contains("docker stop") && $0.command.contains("xyz") }
        XCTAssertNotNil(entry)
    }

    func testRestartRecordsCommand() async {
        let state = makeAppState()
        await state.containerService.restart(containerID: "foo")
        try? await Task.sleep(nanoseconds: 50_000_000)
        let entry = state.commandLog.first { $0.command.contains("docker restart") && $0.command.contains("foo") }
        XCTAssertNotNil(entry)
    }

    func testDeleteRecordsCommand() async {
        let state = makeAppState()
        await state.containerService.delete(containerID: "bar")
        try? await Task.sleep(nanoseconds: 50_000_000)
        let entry = state.commandLog.first { $0.command.contains("docker rm") && $0.command.contains("bar") }
        XCTAssertNotNil(entry)
    }

    func testDeleteForceFlag() async {
        let state = makeAppState()
        await state.containerService.delete(containerID: "baz", force: true)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let entry = state.commandLog.first { $0.command.contains("docker rm") && $0.command.contains("baz") }
        XCTAssertTrue(entry?.command.contains("--force") ?? false)
    }

    func testDeleteWithoutForce() async {
        let state = makeAppState()
        await state.containerService.delete(containerID: "qux", force: false)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let entry = state.commandLog.first { $0.command.contains("docker rm") && $0.command.contains("qux") }
        XCTAssertFalse(entry?.command.contains("--force") ?? true)
    }

    func testNotificationTriggersStart() async {
        let state = makeAppState()
        NotificationCenter.default.post(name: .containerLifecycleStart, object: Set(["n1", "n2"]))
        try? await Task.sleep(nanoseconds: 100_000_000)
        let entries = state.commandLog.filter { $0.command.contains("docker start") }
        XCTAssertGreaterThanOrEqual(entries.count, 2)
    }

    func testLogsAppendsToBuffer() {
        let state = makeAppState()
        let buffer = LogStreamBuffer()
        state.containerService.logs(containerID: "logs1", into: buffer)
        XCTAssertGreaterThan(buffer.lines.count, 0)
        XCTAssertTrue(buffer.lines.contains { $0.text.contains("Streaming logs for logs1") })
    }

    func testLifecycleErrorDescriptions() {
        XCTAssertNotNil(ContainerService.LifecycleError.profileNotSelected.errorDescription)
        XCTAssertNotNil(ContainerService.LifecycleError.containerNotFound(id: "x").errorDescription)
        XCTAssertNotNil(ContainerService.LifecycleError.commandFailed(message: "y").errorDescription)
    }

    // MARK: - Helpers

    private func makeAppState() -> AppState {
        let state = AppState(colima: MockColimaCLI(), profiles: [], userDefaults: nil)
        return state
    }
}

private final class MockColimaCLI: ColimaControlling {
    func listProfiles() async throws -> [ColimaProfile] { [] }
    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "start"]), exitCode: 0, stdout: "ok", stderr: "")
    }
    func stop(profile: String) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "stop"]), exitCode: 0, stdout: "ok", stderr: "")
    }
    func restart(profile: String) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "restart"]), exitCode: 0, stdout: "ok", stderr: "")
    }
    func delete(profile: String) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "delete"]), exitCode: 0, stdout: "ok", stderr: "")
    }
    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "kubernetes"]), exitCode: 0, stdout: "ok", stderr: "")
    }
    func update(profile: String) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "update"]), exitCode: 0, stdout: "ok", stderr: "")
    }
    func template() async throws -> String { "cpu: 2" }
    func configuration(profile: String) async throws -> ProfileConfiguration? { .default }
    func logs(profile: String) async throws -> String { "" }
    func status(profile: String) async throws -> ColimaStatusDetail {
        ColimaStatusDetail(profileName: profile, state: .stopped, runtime: .docker, architecture: .host, vmType: .qemu, mountType: .sshfs, resources: .standard, kubernetes: .disabled, networkAddress: "", socket: "", dockerContext: "", errors: [], rawOutput: "")
    }
    func diagnostics(profile: String?) async -> DiagnosticReport { .empty }
}
