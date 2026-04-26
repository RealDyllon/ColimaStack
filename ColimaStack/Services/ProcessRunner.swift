import Foundation

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

    init(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        launchedAt: Date,
        duration: TimeInterval,
        terminationStatus: Int32,
        standardOutput: String,
        standardError: String
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.launchedAt = launchedAt
        self.duration = duration
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
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

nonisolated struct LiveProcessRunner: ProcessRunner {
    private let baseEnvironment: [String: String]

    init(baseEnvironment: [String: String] = ProcessInfo.processInfo.environment) {
        self.baseEnvironment = baseEnvironment
    }

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let launchedAt = Date()
        let stdoutBuffer = ProcessOutputBuffer()
        let stderrBuffer = ProcessOutputBuffer()

        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.environment = baseEnvironment.merging(request.environment) { _, new in new }
        process.currentDirectoryURL = request.currentDirectoryURL
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
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

        if let input = request.standardInput {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            try stdinPipe.fileHandleForWriting.write(contentsOf: input)
            stdinPipe.fileHandleForWriting.closeFile()
        }

        let termination = request.timeout.map { _ in DispatchSemaphore(value: 0) }
        if let termination {
            process.terminationHandler = { _ in
                termination.signal()
            }
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

        if let timeout = request.timeout {
            if termination?.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
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

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        stdoutBuffer.append(remainingStdout)
        stderrBuffer.append(remainingStderr)
        let stdoutSnapshot = stdoutBuffer.snapshot()
        let stderrSnapshot = stderrBuffer.snapshot()

        let stdout = try decode(stdoutSnapshot, stream: "stdout", executablePath: request.executableURL.path)
        let stderr = try decode(stderrSnapshot, stream: "stderr", executablePath: request.executableURL.path)

        return ProcessResult(
            executableURL: request.executableURL,
            arguments: request.arguments,
            environment: request.environment,
            launchedAt: launchedAt,
            duration: Date().timeIntervalSince(launchedAt),
            terminationStatus: process.terminationStatus,
            standardOutput: stdout,
            standardError: stderr
        )
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
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        let value = data
        lock.unlock()
        return value
    }
}
