import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct StreamingCommandTests {
    @Test func streamingCommandLogAppendsChunksThenSucceeds() async {
        let colima = ChunkedStreamingColima(chunks: ["INFO starting\n", "INFO ready\n"])
        let state = AppState(colima: colima, profiles: [AppStateBackendAggregationTests.profile(named: "default", state: .running)])
        state.selectedProfileID = "default"
        state.useStreamingCommandOutput = true

        await state.startSelected()

        guard let entry = state.commandLog.first else {
            Issue.record("Expected a command log entry")
            return
        }
        #expect(entry.command == "Start default")
        #expect(entry.status == .succeeded)
        // The final output should contain both chunks.
        #expect(entry.output.contains("starting"))
        #expect(entry.output.contains("ready"))
    }

    @Test func streamingCommandFailureSetsFailedStatusAndError() async {
        let colima = ChunkedStreamingColima(chunks: ["INFO starting\n"], terminalStatus: 1)
        let state = AppState(colima: colima, profiles: [AppStateBackendAggregationTests.profile(named: "default", state: .running)])
        state.selectedProfileID = "default"
        state.useStreamingCommandOutput = true

        await state.startSelected()

        guard let entry = state.commandLog.first else {
            Issue.record("Expected a command log entry")
            return
        }
        if case .failed = entry.status {
            // expected
        } else {
            Issue.record("Expected failed status, got \(entry.status)")
        }
        #expect(state.presentedError != nil)
    }

    @Test func cancelCurrentCommandStopsRunningCommand() async {
        let colima = HangingStreamingColima()
        let state = AppState(colima: colima, profiles: [AppStateBackendAggregationTests.profile(named: "default", state: .running)])
        state.selectedProfileID = "default"
        state.useStreamingCommandOutput = true

        let task = Task { await state.startSelected() }
        try? await Task.sleep(nanoseconds: 100_000_000)
        state.cancelCurrentCommand()
        await task.value

        guard let entry = state.commandLog.first else {
            Issue.record("Expected a command log entry")
            return
        }
        if case .failed = entry.status {
            // expected — cancelled commands are recorded as failed
        } else {
            Issue.record("Expected failed status after cancel, got \(entry.status)")
        }
        #expect(state.activeOperation == nil)
    }
}

// MARK: - Fake streaming colima CLI

@MainActor
final class ChunkedStreamingColima: ColimaControlling {
    let chunks: [String]
    let terminalStatus: Int32

    init(chunks: [String], terminalStatus: Int32 = 0) {
        self.chunks = chunks
        self.terminalStatus = terminalStatus
    }

    func diagnostics(profile: String?) async -> DiagnosticReport { .empty }
    func listProfiles() async throws -> [ColimaProfile] { [] }
    func status(profile: String) async throws -> ColimaStatusDetail {
        AppStateBackendAggregationTests.detail(profile: profile, state: .running)
    }
    func logs(profile: String) async throws -> String { "" }
    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "start"]), exitCode: terminalStatus, stdout: chunks.joined(), stderr: "")
    }
    func stop(profile: String) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "stop"]), exitCode: 0, stdout: "", stderr: "") }
    func restart(profile: String) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "restart"]), exitCode: 0, stdout: "", stderr: "") }
    func delete(profile: String) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "delete"]), exitCode: 0, stdout: "", stderr: "") }
    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "kubernetes"]), exitCode: 0, stdout: "", stderr: "") }
    func update(profile: String) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "update"]), exitCode: 0, stdout: "", stderr: "") }
    func template() async throws -> String { "" }
    func configuration(profile: String) async throws -> ProfileConfiguration? { nil }

    // Override the default streaming implementation to yield chunks one-by-one.
    func streamStart(_ configuration: ProfileConfiguration, cancellation: ProcessCancellation?) -> AsyncThrowingStream<StreamingProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for chunk in self.chunks {
                    continuation.yield(.chunk(.stdout(Data(chunk.utf8))))
                }
                let result = ProcessResult(
                    request: ProcessRequest(arguments: ["colima", "start"]),
                    exitCode: self.terminalStatus,
                    stdout: self.chunks.joined(),
                    stderr: ""
                )
                continuation.yield(.result(result))
                continuation.finish()
            }
        }
    }
}

@MainActor
final class HangingStreamingColima: ColimaControlling {
    func diagnostics(profile: String?) async -> DiagnosticReport { .empty }
    func listProfiles() async throws -> [ColimaProfile] { [] }
    func status(profile: String) async throws -> ColimaStatusDetail {
        AppStateBackendAggregationTests.detail(profile: profile, state: .running)
    }
    func logs(profile: String) async throws -> String { "" }
    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult {
        ProcessResult(request: ProcessRequest(arguments: ["colima", "start"]), exitCode: 0, stdout: "", stderr: "")
    }
    func stop(profile: String) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "stop"]), exitCode: 0, stdout: "", stderr: "") }
    func restart(profile: String) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "restart"]), exitCode: 0, stdout: "", stderr: "") }
    func delete(profile: String) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "delete"]), exitCode: 0, stdout: "", stderr: "") }
    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "kubernetes"]), exitCode: 0, stdout: "", stderr: "") }
    func update(profile: String) async throws -> ProcessResult { ProcessResult(request: ProcessRequest(arguments: ["colima", "update"]), exitCode: 0, stdout: "", stderr: "") }
    func template() async throws -> String { "" }
    func configuration(profile: String) async throws -> ProfileConfiguration? { nil }

    func streamStart(_ configuration: ProfileConfiguration, cancellation: ProcessCancellation?) -> AsyncThrowingStream<StreamingProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            // Never yields; hangs until cancelled. The CancellationError from
            // ProcessCancellation.cancel() finishes the stream.
            // We rely on the default runStreamingCommand catching the cancellation.
            Task {
                // Simulate a long-running process that gets cancelled.
                let task = Task<Void, Never> {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                }
                // Wait for cancellation via the ProcessCancellation
                while cancellation?.isCancelled == false {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
                task.cancel()
                continuation.finish(throwing: CancellationError())
            }
        }
    }
}
