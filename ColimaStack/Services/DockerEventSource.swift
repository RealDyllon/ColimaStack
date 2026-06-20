import Foundation

/// Event source for Docker engine events. Bootstraps with a full `docker ps/images/
/// volume ls/network ls` snapshot, then runs a long-lived `docker events --format
/// '{{json .}}'` stream. On any engine event, re-snapshots the affected resource kind
/// and publishes a `SnapshotReplaced` with the updated docker slice. Reconnects with
/// exponential backoff when the stream drops.
///
/// For non-Docker runtimes (containerd/incus), publishes a `disconnected` connection
/// state and finishes immediately without starting a stream.
final class DockerEventSource: RuntimeEventSource, @unchecked Sendable {
    private let profile: ColimaProfile
    private let status: ColimaStatusDetail
    private let dockerProvider: DockerResourceProviding
    private let streamingRunner: StreamingProcessRunning
    private let toolLocator: ToolLocator
    private let environment: [String: String]
    private let executionMode: LiveColimaCLI.ExecutionMode
    private let maxReconnectInterval: TimeInterval

    init(
        profile: ColimaProfile,
        status: ColimaStatusDetail,
        dockerProvider: DockerResourceProviding = LiveDockerResourceService(),
        streamingRunner: StreamingProcessRunning = LiveStreamingProcessRunner(),
        toolLocator: ToolLocator = LiveToolLocator(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executionMode: LiveColimaCLI.ExecutionMode = .resolvedPath,
        maxReconnectInterval: TimeInterval = 30
    ) {
        self.profile = profile
        self.status = status
        self.dockerProvider = dockerProvider
        self.streamingRunner = streamingRunner
        self.toolLocator = toolLocator
        self.environment = environment
        self.executionMode = executionMode
        self.maxReconnectInterval = maxReconnectInterval
    }

    func events() -> AsyncThrowingStream<RuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Skip for non-Docker runtimes.
                let runtime = status.runtime ?? profile.runtime
                guard runtime == .docker else {
                    continuation.yield(.connectionStateChanged(source: .docker, state: .disconnected))
                    continuation.finish()
                    return
                }

                // Skip if docker is not installed.
                guard toolLocator.locate("docker") != nil else {
                    continuation.yield(.connectionStateChanged(source: .docker, state: .failed(reason: "Docker CLI not found")))
                    continuation.finish()
                    return
                }

                let context = status.dockerContext.isEmpty ? profile.dockerContext : status.dockerContext

                var attempt = 0
                while !Task.isCancelled {
                    // Bootstrap: full snapshot, publish SnapshotReplaced.
                    continuation.yield(.connectionStateChanged(source: .docker, state: attempt == 0 ? .connecting : .reconnecting(attempt: attempt)))
                    do {
                        let snapshot = try await dockerProvider.snapshot(context: context)
                        let slice = DockerResourceSnapshotSlice(
                            context: snapshot.context,
                            containers: snapshot.containers,
                            images: snapshot.images,
                            volumes: snapshot.volumes,
                            networks: snapshot.networks,
                            stats: snapshot.stats,
                            diskUsage: snapshot.diskUsage
                        )
                        continuation.yield(.snapshotReplaced(source: .docker, docker: slice, kubernetes: nil))
                        continuation.yield(.connectionStateChanged(source: .docker, state: .connected))
                        attempt = 0
                    } catch {
                        continuation.yield(.issue(BackendIssue(
                            severity: .warning,
                            source: .docker,
                            title: "Docker bootstrap failed",
                            message: error.localizedDescription
                        )))
                    }

                    // Run the docker events stream.
                    do {
                        let request = try buildEventsRequest(context: context)
                        let stream = streamingRunner.run(request, cancellation: nil)
                        for try await event in stream {
                            if Task.isCancelled { break }
                            switch event {
                            case .chunk(let chunk):
                                handleEventsChunk(chunk, context: context, continuation: continuation)
                            case .result:
                                // Process exited; we'll reconnect below.
                                break
                            }
                        }
                    } catch is CancellationError {
                        continuation.finish()
                        return
                    } catch {
                        // Stream error; publish issue and reconnect.
                        continuation.yield(.issue(BackendIssue(
                            severity: .warning,
                            source: .docker,
                            title: "Docker events stream ended",
                            message: error.localizedDescription
                        )))
                    }

                    if Task.isCancelled { break }

                    // Reconnect with exponential backoff + jitter.
                    attempt += 1
                    let delay = min(maxReconnectInterval, pow(2.0, Double(attempt))) + Double.random(in: 0...0.5)
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Event line handling

    private func handleEventsChunk(_ chunk: ProcessChunk, context: String?, continuation: AsyncThrowingStream<RuntimeEvent, Error>.Continuation) {
        let text = chunk.redactedString()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let obj = JSONCommandParser.object(trimmed) else {
                // Malformed line: drop with a warning issue.
                continuation.yield(.issue(BackendIssue(
                    severity: .warning,
                    source: .docker,
                    title: "Dropped malformed Docker event line",
                    message: "A line from `docker events` was not valid JSON and was ignored."
                )))
                continue
            }
            // We don't parse the event into a per-item delta here; instead we re-snapshot
            // the affected resource kind and publish SnapshotReplaced. This is simpler and
            // correct; a future optimization can use `docker inspect <id>` for true deltas.
            // For now, any docker event triggers a full re-snapshot on the next iteration.
            // (The re-snapshot happens implicitly: the event stream continues, and we
            // re-bootstrap on reconnect. For mid-stream updates, we re-snapshot here.)
            handleDockerEvent(obj, context: context, continuation: continuation)
        }
    }

    /// On any docker event, re-snapshot and publish the updated slice. This is a
    /// deliberate simplification: rather than parsing the event into a precise delta,
    /// we re-run the snapshot commands (only triggered by an actual engine event,
    /// not on a timer) and publish the full updated slice. This is still a massive
    /// improvement over polling since it only fires when something actually changes.
    private func handleDockerEvent(_ obj: [String: Any], context: String?, continuation: AsyncThrowingStream<RuntimeEvent, Error>.Continuation) {
        // The event JSON has a "Type" field (container/image/volume/network).
        // We use it only to decide whether to re-snapshot; the SnapshotReplaced
        // event carries the full updated docker slice.
        let _ = obj.string("Type", "type")
        // For Phase 2, we re-snapshot the full docker state on any event.
        // A follow-up can optimize to re-snapshot only the affected resource kind.
        Task {
            do {
                let snapshot = try await dockerProvider.snapshot(context: context)
                let slice = DockerResourceSnapshotSlice(
                    context: snapshot.context,
                    containers: snapshot.containers,
                    images: snapshot.images,
                    volumes: snapshot.volumes,
                    networks: snapshot.networks,
                    stats: snapshot.stats,
                    diskUsage: snapshot.diskUsage
                )
                continuation.yield(.snapshotReplaced(source: .docker, docker: slice, kubernetes: nil))
            } catch {
                // Re-snapshot failed; ignore — the events stream continues and the
                // next reconnect will re-bootstrap.
            }
        }
    }

    // MARK: - Process request

    private func buildEventsRequest(context: String?) throws -> ProcessRequest {
        do {
            let dockerURL = try toolLocator.require("docker")
            let executableURL: URL
            let arguments: [String]
            switch executionMode {
            case .env:
                executableURL = URL(fileURLWithPath: "/usr/bin/env")
                arguments = ["docker"] + dockerArguments(context: context, subcommand: ["events", "--format", "{{json .}}"])
            case .resolvedPath:
                executableURL = dockerURL
                arguments = dockerArguments(context: context, subcommand: ["events", "--format", "{{json .}}"])
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
}
