import Foundation
import Darwin

// MARK: - Streaming chunk

nonisolated enum ProcessChunk: Sendable {
    case stdout(Data)
    case stderr(Data)
}

// MARK: - Streaming protocol

protocol StreamingProcessRunning: Sendable {
    /// Run a process and yield stdout/stderr chunks as they arrive, terminating with
    /// a final `ProcessResult` (or `ProcessRunnerError`/`CancellationError`).
    /// Cancellation is cooperative via `ProcessCancellation` and Swift task cancellation.
    func run(_ request: ProcessRequest, cancellation: ProcessCancellation?) -> AsyncThrowingStream<StreamingProcessEvent, Error>
}

// MARK: - Streaming event (chunk or terminal)

nonisolated enum StreamingProcessEvent: Sendable {
    case chunk(ProcessChunk)
    case result(ProcessResult)
}

// MARK: - Live streaming runner

final class LiveStreamingProcessRunner: StreamingProcessRunning, @unchecked Sendable {
    private static let ignoreSIGPIPE: Void = {
        signal(SIGPIPE, SIG_IGN)
    }()

    private let outputLimitBytes: Int

    init(outputLimitBytes: Int = LiveProcessRunner.defaultOutputLimitBytes) {
        self.outputLimitBytes = outputLimitBytes
    }

    func run(_ request: ProcessRequest, cancellation: ProcessCancellation?) -> AsyncThrowingStream<StreamingProcessEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<StreamingProcessEvent, Error>.makeStream(
            of: StreamingProcessEvent.self,
            throwing: Error.self
        )
        let limit = outputLimitBytes
        let timeoutBox = TimeoutBox()
        let processBox = ProcessBox()
        let bufferBox = BufferBox(limit: limit)

        // Drive the stream from a detached task so the consumer's cancellation propagates
        // and the producer doesn't block the caller's actor.
        let producer = Task.detached(priority: .utility) {
            await Self.produce(
                request: request,
                cancellation: cancellation,
                timeoutBox: timeoutBox,
                processBox: processBox,
                bufferBox: bufferBox,
                continuation: continuation
            )
        }

        // Start a cooperative timeout task that terminates the process if the timeout
        // elapses. The timeout task is cancelled when the consumer cancels or the process
        // exits naturally.
        if let timeout = request.timeout {
            let timeoutBoxRef = timeoutBox
            let processBoxRef = processBox
            let timeoutTask = Task.detached(priority: .utility) {
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                } catch {
                    return
                }
                guard let proc = processBoxRef.process, proc.isRunning else { return }
                await MainActor.run {
                    timeoutBoxRef.didTimeout = true
                    proc.terminate()
                }
                // Escalate to interrupt / kill if the process doesn't exit promptly.
                for delay: UInt64 in [200_000_000, 1_000_000_000] {
                    try? await Task.sleep(nanoseconds: delay)
                    guard let p = processBoxRef.process, p.isRunning else { return }
                    await MainActor.run {
                        if delay == 200_000_000 {
                            p.interrupt()
                        } else {
                            kill(p.processIdentifier, SIGKILL)
                        }
                    }
                }
            }
            continuation.onTermination = { _ in
                producer.cancel()
                timeoutTask.cancel()
            }
        } else {
            continuation.onTermination = { _ in
                producer.cancel()
            }
        }
        return stream
    }

    /// Produce events for a single process. Runs on the main actor because `Process`
    /// and `Pipe` are main-actor-isolated under the project's build setting.
    @MainActor
    private static func produce(
        request: ProcessRequest,
        cancellation: ProcessCancellation?,
        timeoutBox: TimeoutBox,
        processBox: ProcessBox,
        bufferBox: BufferBox,
        continuation: AsyncThrowingStream<StreamingProcessEvent, Error>.Continuation
    ) async {
        _ = ignoreSIGPIPE

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        processBox.process = process
        let launchedAt = Date()

        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.environment = request.environment
        process.currentDirectoryURL = request.currentDirectoryURL
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let chunkSender = ChunkSender(continuation: continuation)
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            bufferBox.stdout.append(data)
            chunkSender.send(.stdout(data))
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            bufferBox.stderr.append(data)
            chunkSender.send(.stderr(data))
        }

        if cancellation?.isCancelled == true {
            continuation.finish(throwing: CancellationError())
            return
        }

        // Launch the process up-front so a launch failure surfaces immediately.
        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            continuation.finish(throwing: ProcessRunnerError.failedToLaunch(
                executablePath: request.executableURL.path,
                underlyingMessage: error.localizedDescription
            ))
            return
        }
        cancellation?.bind(process)

        // Wait for process exit (resumed by the termination handler on the main actor).
        let _: Void = await withCheckedContinuation { (cc: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { proc in
                Task { @MainActor in
                    if timeoutBox.didTimeout {
                        continuation.finish(throwing: ProcessRunnerError.timedOut(
                            executablePath: request.executableURL.path,
                            arguments: request.arguments,
                            timeout: request.timeout ?? 0
                        ))
                    } else {
                        let result = makeResult(
                            request: request,
                            process: proc,
                            launchedAt: launchedAt,
                            bufferBox: bufferBox,
                            stdoutPipe: stdoutPipe,
                            stderrPipe: stderrPipe
                        )
                        continuation.yield(.result(result))
                        continuation.finish()
                    }
                    cc.resume()
                }
            }
        }

        // Cleanup readability handlers and cancellation binding.
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        if let cancellation, let proc = processBox.process {
            cancellation.clear(proc)
        }
    }

    @MainActor
    private static func makeResult(
        request: ProcessRequest,
        process: Process,
        launchedAt: Date,
        bufferBox: BufferBox,
        stdoutPipe: Pipe,
        stderrPipe: Pipe
    ) -> ProcessResult {
        // Drain any tail bytes the readability handler hasn't yet observed.
        let tailOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let tailErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if !tailOut.isEmpty { bufferBox.stdout.append(tailOut) }
        if !tailErr.isEmpty { bufferBox.stderr.append(tailErr) }
        let outSnap = bufferBox.stdout.snapshot()
        let errSnap = bufferBox.stderr.snapshot()
        let stdout = decode(outSnap.data)
        let stderr = decode(errSnap.data)
        return ProcessResult(
            executableURL: request.executableURL,
            arguments: request.arguments,
            environment: request.environment,
            launchedAt: launchedAt,
            duration: Date().timeIntervalSince(launchedAt),
            terminationStatus: process.terminationStatus,
            standardOutput: stdout,
            standardError: stderr,
            standardOutputTruncated: outSnap.truncated,
            standardErrorTruncated: errSnap.truncated
        )
    }

    private nonisolated static func decode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        if let value = String(data: data, encoding: .utf8) { return value }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Timeout / process / buffer boxes

private final class TimeoutBox: @unchecked Sendable {
    var didTimeout = false
}

private final class ProcessBox: @unchecked Sendable {
    var process: Process?
}

private final class BufferBox: @unchecked Sendable {
    let stdout: ProcessOutputBuffer
    let stderr: ProcessOutputBuffer
    init(limit: Int) {
        self.stdout = ProcessOutputBuffer(limit: limit)
        self.stderr = ProcessOutputBuffer(limit: limit)
    }
}

// MARK: - Chunk sender

private final class ChunkSender: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<StreamingProcessEvent, Error>.Continuation?

    init(continuation: AsyncThrowingStream<StreamingProcessEvent, Error>.Continuation) {
        self.continuation = continuation
    }

    func send(_ chunk: ProcessChunk) {
        lock.lock()
        let cont = continuation
        lock.unlock()
        cont?.yield(.chunk(chunk))
    }
}

// MARK: - Redaction pass for streamed chunks

extension ProcessChunk {
    /// Decode the chunk as UTF-8 (lossy fallback) and return the redacted string suitable
    /// for display in the UI / command log. Idempotent for re-application.
    func redactedString() -> String {
        let data: Data
        switch self {
        case .stdout(let d): data = d
        case .stderr(let d): data = d
        }
        guard !data.isEmpty else { return "" }
        let raw = String(decoding: data, as: UTF8.self)
        return EnvironmentRedactor.redacted(raw)
    }
}
