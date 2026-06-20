import Foundation

// MARK: - Streaming Docker stats protocol

protocol StreamingDockerStatsProviding: Sendable {
    /// Stream `docker stats` output as one `DockerStatsResource` per JSON line, for the
    /// given Docker context. The stream is long-lived (no `--no-stream` flag) and is
    /// cancelled via the supplied `ProcessCancellation` or by cancelling the consuming
    /// `Task`.
    func streamStats(context: String?, cancellation: ProcessCancellation?) -> AsyncThrowingStream<DockerStatsResource, Error>
}

// MARK: - Live streaming Docker stats service

final class LiveStreamingDockerStatsService: StreamingDockerStatsProviding, @unchecked Sendable {
    private let streamingRunner: StreamingProcessRunning
    private let toolLocator: ToolLocator
    private let environment: [String: String]
    private let executionMode: LiveColimaCLI.ExecutionMode

    init(
        streamingRunner: StreamingProcessRunning = LiveStreamingProcessRunner(),
        toolLocator: ToolLocator = LiveToolLocator(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executionMode: LiveColimaCLI.ExecutionMode = .resolvedPath
    ) {
        self.streamingRunner = streamingRunner
        self.toolLocator = toolLocator
        self.environment = environment
        self.executionMode = executionMode
    }

    func streamStats(context: String?, cancellation: ProcessCancellation?) -> AsyncThrowingStream<DockerStatsResource, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let request: ProcessRequest
                do {
                    request = try self.buildStatsRequest(context: context)
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                do {
                    for try await event in self.streamingRunner.run(request, cancellation: cancellation) {
                        switch event {
                        case .chunk(let chunk):
                            let text = chunk.redactedString()
                            // `docker stats --format json` emits one JSON object per line.
                            for line in text.components(separatedBy: .newlines) {
                                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty, let obj = JSONCommandParser.object(trimmed) else { continue }
                                if let stats = Self.stats(obj) {
                                    continuation.yield(stats)
                                }
                            }
                        case .result:
                            // Process exited; finish the stats stream. The caller
                            // (event source) will reconnect with backoff.
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildStatsRequest(context: String?) throws -> ProcessRequest {
        do {
            let dockerURL = try toolLocator.require("docker")
            let executableURL: URL
            let arguments: [String]
            switch executionMode {
            case .env:
                executableURL = URL(fileURLWithPath: "/usr/bin/env")
                arguments = ["docker"] + dockerArguments(context: context, subcommand: ["stats", "--format", "{{json .}}"])
            case .resolvedPath:
                executableURL = dockerURL
                arguments = dockerArguments(context: context, subcommand: ["stats", "--format", "{{json .}}"])
            }
            var env: [String: String] = [:]
            let searchPath = toolLocator.searchPaths().joined(separator: ":")
            if !searchPath.isEmpty { env["PATH"] = searchPath }
            return ProcessRequest(
                executableURL: executableURL,
                arguments: arguments,
                environment: env,
                timeout: nil
            )
        } catch let error as ToolLocatorError {
            switch error {
            case let .toolNotFound(name, searchPaths):
                throw ColimaCLIError.missingTool(name: name, searchPaths: searchPaths)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ColimaCLIError.processFailure(underlying: EnvironmentRedactor.redacted(error.localizedDescription))
        }
    }

    private func dockerArguments(context: String?, subcommand: [String]) -> [String] {
        guard let context, !context.isEmpty else { return subcommand }
        return ["--context", context] + subcommand
    }

    private static func stats(_ object: [String: Any]) -> DockerStatsResource? {
        let id = object.string("Container", "ID")
        let name = object.string("Name")
        guard !id.isEmpty || !name.isEmpty else { return nil }
        return DockerStatsResource(
            id: id.isEmpty ? name : id,
            name: name,
            cpuPercent: object.string("CPUPerc"),
            memoryUsage: object.string("MemUsage"),
            memoryPercent: object.string("MemPerc"),
            networkIO: object.string("NetIO"),
            blockIO: object.string("BlockIO"),
            pids: object.string("PIDs")
        )
    }
}
