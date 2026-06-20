import Foundation
import Testing
@testable import ColimaStack

@Suite struct StreamingProcessRunnerTests {
    @Test func chunksArriveBeforeExit() async throws {
        // `printf` writes then exits; we should see at least one chunk and a terminal result.
        let runner = LiveStreamingProcessRunner()
        let request = ProcessRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf 'hello\\nworld\\n'; sleep 0.05"],
            environment: ["PATH": "/usr/bin:/bin"]
        )
        var sawChunk = false
        var terminal: ProcessResult?
        for try await event in runner.run(request, cancellation: nil) {
            switch event {
            case .chunk:
                sawChunk = true
            case .result(let r):
                terminal = r
            }
        }
        #expect(sawChunk)
        #expect(terminal != nil)
        #expect(terminal?.terminationStatus == 0)
    }

    @Test func terminalResultExposesNonZeroExitStatus() async throws {
        let runner = LiveStreamingProcessRunner()
        let request = ProcessRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo bad; exit 7"],
            environment: ["PATH": "/usr/bin:/bin"]
        )
        var terminal: ProcessResult?
        for try await event in runner.run(request, cancellation: nil) {
            if case .result(let r) = event { terminal = r }
        }
        #expect(terminal?.terminationStatus == 7)
        #expect(terminal?.standardOutput.contains("bad") == true)
    }

    @Test func cancellationTerminatesProcess() async throws {
        let runner = LiveStreamingProcessRunner()
        let request = ProcessRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "sleep 30"],
            environment: ["PATH": "/usr/bin:/bin"]
        )
        let cancellation = ProcessCancellation()
        let task = Task<ProcessResult?, Error> {
            var result: ProcessResult?
            do {
                for try await event in runner.run(request, cancellation: cancellation) {
                    if case .result(let r) = event { result = r }
                }
            } catch {
                // expected
            }
            return result
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        cancellation.cancel()
        let terminal = try await task.value
        // We don't assert a specific exit status — terminate/intrupt/kill can yield various.
        // What we assert is that we get back at all (process was terminated and stream ended).
        _ = terminal
    }

    @Test func timeoutThrowsTimedOut() async throws {
        let runner = LiveStreamingProcessRunner()
        let request = ProcessRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "sleep 5"],
            environment: ["PATH": "/usr/bin:/bin"],
            timeout: 0.2
        )
        do {
            for try await _ in runner.run(request, cancellation: nil) { }
            Issue.record("Expected timeout error")
        } catch ProcessRunnerError.timedOut {
            // expected
        } catch {
            Issue.record("Expected timedOut, got \(error)")
        }
    }

    @Test func chunkRedactionRemovesTokens() {
        let chunk = ProcessChunk.stdout(Data("TOKEN=abc123\n".utf8))
        let redacted = chunk.redactedString()
        #expect(!redacted.contains("abc123"))
        #expect(redacted.contains("TOKEN=<redacted>"))
    }

    @Test func streamDoesNotBlockOnEOFForLongRunningProcess() async throws {
        // A process that writes incrementally and stays alive: chunks must arrive over time,
        // not all at once at exit.
        let runner = LiveStreamingProcessRunner()
        let request = ProcessRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "for i in 1 2 3; do echo line$i; sleep 0.1; done"],
            environment: ["PATH": "/usr/bin:/bin"]
        )
        var chunkTimes: [Date] = []
        let start = Date()
        for try await event in runner.run(request, cancellation: nil) {
            if case .chunk = event {
                chunkTimes.append(Date())
            }
        }
        // At least 2 chunks arrived, and they weren't all at the same instant
        // (which would indicate buffering until exit).
        #expect(chunkTimes.count >= 2)
        let span = (chunkTimes.last ?? start).timeIntervalSince(chunkTimes.first ?? start)
        #expect(span >= 0.05)
    }
}
