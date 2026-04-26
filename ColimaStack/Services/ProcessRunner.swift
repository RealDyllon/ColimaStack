import Foundation
import Darwin

nonisolated protocol CombinedProcessOutput {
    var standardOutput: String { get }
    var standardError: String { get }
}

nonisolated extension CombinedProcessOutput {
    var combinedOutput: String {
        switch (standardOutput.isEmpty, standardError.isEmpty) {
        case (true, true):
            return ""
        case (false, true):
            return standardOutput
        case (true, false):
            return standardError
        case (false, false):
            return standardOutput + "\n" + standardError
        }
    }
}

nonisolated struct ProcessRequest: Hashable, Sendable {
    var executableURL: URL
    var arguments: [String]
    var environment: [String: String]
    var currentDirectoryURL: URL?
    var standardInput: Data?
    var timeout: TimeInterval?

    init(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectoryURL: URL? = nil,
        standardInput: Data? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.currentDirectoryURL = currentDirectoryURL
        self.standardInput = standardInput
        self.timeout = timeout
    }

    init(arguments: [String], environment: [String: String] = [:]) {
        self.init(executableURL: URL(fileURLWithPath: "/usr/bin/env"), arguments: arguments, environment: environment)
    }
}

nonisolated struct ProcessResult: Hashable, Sendable, CombinedProcessOutput {
    var executableURL: URL
    var arguments: [String]
    var environment: [String: String]
    var launchedAt: Date
    var duration: TimeInterval
    var terminationStatus: Int32
    var standardOutput: String
    var standardError: String
    var standardOutputTruncated: Bool
    var standardErrorTruncated: Bool

    init(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        launchedAt: Date,
        duration: TimeInterval,
        terminationStatus: Int32,
        standardOutput: String,
        standardError: String,
        standardOutputTruncated: Bool = false,
        standardErrorTruncated: Bool = false
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.launchedAt = launchedAt
        self.duration = duration
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.standardOutputTruncated = standardOutputTruncated
        self.standardErrorTruncated = standardErrorTruncated
    }

    init(request: ProcessRequest, exitCode: Int32, stdout: String, stderr: String) {
        self.init(
            executableURL: request.executableURL,
            arguments: request.arguments,
            environment: request.environment,
            launchedAt: Date(),
            duration: 0,
            terminationStatus: exitCode,
            standardOutput: stdout,
            standardError: stderr
        )
    }

}

nonisolated enum ProcessRunnerError: LocalizedError, Sendable {
    case failedToLaunch(executablePath: String, underlyingMessage: String)
    case timedOut(executablePath: String, arguments: [String], timeout: TimeInterval)
    case invalidUTF8(stream: String, executablePath: String)

    var errorDescription: String? {
        switch self {
        case let .failedToLaunch(executablePath, underlyingMessage):
            return "Failed to launch \(executablePath): \(underlyingMessage)"
        case let .timedOut(executablePath, arguments, timeout):
            return "Timed out after \(timeout)s running \(([executablePath] + arguments).joined(separator: " "))"
        case let .invalidUTF8(stream, executablePath):
            return "Unable to decode \(stream) as UTF-8 for \(executablePath)"
        }
    }
}

nonisolated protocol ProcessRunner {
    func run(_ request: ProcessRequest) throws -> ProcessResult
}

nonisolated protocol CancellableProcessRunner: ProcessRunner {
    func run(_ request: ProcessRequest, cancellation: ProcessCancellation?) throws -> ProcessResult
}

nonisolated final class ProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value
    }

    func bind(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    func clear(_ process: Process) {
        lock.lock()
        if self.process === process {
            self.process = nil
        }
        lock.unlock()
    }

    func cancel() {
        let process: Process?
        lock.lock()
        cancelled = true
        process = self.process
        lock.unlock()

        guard let process, process.isRunning else { return }
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            guard process.isRunning else { return }
            process.interrupt()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                guard process.isRunning else { return }
                kill(process.processIdentifier, SIGKILL)
            }
        }
    }
}

nonisolated struct LiveProcessRunner: CancellableProcessRunner {
    static let defaultOutputLimitBytes = 1_048_576
    private static let ignoreSIGPIPE: Void = {
        signal(SIGPIPE, SIG_IGN)
    }()

    private static let inheritedEnvironmentKeys: Set<String> = [
        "HOME",
        "LANG",
        "LC_ALL",
        "LC_COLLATE",
        "LC_CTYPE",
        "LC_MESSAGES",
        "LC_MONETARY",
        "LC_NUMERIC",
        "LC_TIME",
        "PATH",
        "TMP",
        "TMPDIR",
        "TEMP"
    ]

    private let baseEnvironment: [String: String]
    private let outputLimitBytes: Int

    init(
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        outputLimitBytes: Int = Self.defaultOutputLimitBytes
    ) {
        self.baseEnvironment = baseEnvironment
        self.outputLimitBytes = outputLimitBytes
    }

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        try run(request, cancellation: nil)
    }

    func run(_ request: ProcessRequest, cancellation: ProcessCancellation?) throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let launchedAt = Date()
        let stdoutBuffer = ProcessOutputBuffer(limit: outputLimitBytes)
        let stderrBuffer = ProcessOutputBuffer(limit: outputLimitBytes)
        let stdinPipe = request.standardInput.map { _ in Pipe() }
        _ = Self.ignoreSIGPIPE

        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.environment = environment(for: request.environment)
        process.currentDirectoryURL = request.currentDirectoryURL
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        if let stdinPipe {
            process.standardInput = stdinPipe
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutBuffer.append(data)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrBuffer.append(data)
        }
        defer {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
        }

        let termination = request.timeout.map { _ in DispatchSemaphore(value: 0) }
        if let termination {
            process.terminationHandler = { _ in
                termination.signal()
            }
        }
        cancellation?.bind(process)
        defer {
            cancellation?.clear(process)
        }
        if cancellation?.isCancelled == true {
            throw CancellationError()
        }

        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            throw ProcessRunnerError.failedToLaunch(
                executablePath: request.executableURL.path,
                underlyingMessage: error.localizedDescription
            )
        }

        if let input = request.standardInput, let stdinPipe {
            DispatchQueue.global(qos: .utility).async {
                defer {
                    try? stdinPipe.fileHandleForWriting.close()
                }
                try? stdinPipe.fileHandleForWriting.write(contentsOf: input)
            }
        }

        if let timeout = request.timeout {
            if termination?.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                if termination?.wait(timeout: .now() + 2) == .timedOut {
                    process.interrupt()
                }
                if termination?.wait(timeout: .now() + 1) == .timedOut {
                    kill(process.processIdentifier, SIGKILL)
                }
                process.waitUntilExit()
                throw ProcessRunnerError.timedOut(
                    executablePath: request.executableURL.path,
                    arguments: request.arguments,
                    timeout: timeout
                )
            }
            process.terminationHandler = nil
        } else {
            process.waitUntilExit()
        }

        if cancellation?.isCancelled == true {
            throw CancellationError()
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        stdoutBuffer.append(remainingStdout)
        stderrBuffer.append(remainingStderr)
        let stdoutSnapshot = stdoutBuffer.snapshot()
        let stderrSnapshot = stderrBuffer.snapshot()

        let stdout = try decode(stdoutSnapshot.data, stream: "stdout", executablePath: request.executableURL.path)
        let stderr = try decode(stderrSnapshot.data, stream: "stderr", executablePath: request.executableURL.path)

        return ProcessResult(
            executableURL: request.executableURL,
            arguments: request.arguments,
            environment: request.environment,
            launchedAt: launchedAt,
            duration: Date().timeIntervalSince(launchedAt),
            terminationStatus: process.terminationStatus,
            standardOutput: stdout,
            standardError: stderr,
            standardOutputTruncated: stdoutSnapshot.truncated,
            standardErrorTruncated: stderrSnapshot.truncated
        )
    }

    private func environment(for overrides: [String: String]) -> [String: String] {
        let inherited = baseEnvironment.filter { key, value in
            !value.isEmpty && Self.inheritedEnvironmentKeys.contains(key)
        }
        return inherited.merging(overrides) { _, new in new }
    }

    private func decode(_ data: Data, stream: String, executablePath: String) throws -> String {
        guard !data.isEmpty else { return "" }
        guard let value = String(data: data, encoding: .utf8) else {
            throw ProcessRunnerError.invalidUTF8(stream: stream, executablePath: executablePath)
        }
        return value
    }
}

nonisolated private final class ProcessOutputBuffer: @unchecked Sendable {
    struct Snapshot {
        var data: Data
        var truncated: Bool
    }

    private let lock = NSLock()
    private let limit: Int
    private var data = Data()
    private var droppedByteCount = 0

    init(limit: Int) {
        self.limit = max(limit, 0)
    }

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }
        lock.lock()
        if data.count < limit {
            let available = limit - data.count
            data.append(newData.prefix(available))
            if newData.count > available {
                droppedByteCount += newData.count - available
            }
        } else {
            droppedByteCount += newData.count
        }
        lock.unlock()
    }

    func snapshot() -> Snapshot {
        lock.lock()
        var value = data
        let droppedByteCount = droppedByteCount
        lock.unlock()
        if droppedByteCount > 0 {
            value.append(Data("\n[output truncated; dropped \(droppedByteCount) bytes]".utf8))
        }
        return Snapshot(data: value, truncated: droppedByteCount > 0)
    }
}
