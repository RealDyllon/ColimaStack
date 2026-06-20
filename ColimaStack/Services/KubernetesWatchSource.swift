import Foundation

/// Event source for Kubernetes resources. Bootstraps with a full `kubectl get` snapshot
/// (nodes, namespaces, pods, services, deployments), then runs a long-lived
/// `kubectl get pods -A -w -o json` watch. On any watch event, re-snapshots the full
/// k8s state and publishes a `SnapshotReplaced`. Reconnects with exponential backoff.
///
/// When Kubernetes is disabled for the profile, publishes a `disconnected` connection
/// state and finishes immediately.
final class KubernetesWatchSource: RuntimeEventSource, @unchecked Sendable {
    private let profile: ColimaProfile
    private let status: ColimaStatusDetail
    private let kubernetesProvider: KubernetesResourceProviding
    private let streamingRunner: StreamingProcessRunning
    private let toolLocator: ToolLocator
    private let environment: [String: String]
    private let executionMode: LiveColimaCLI.ExecutionMode
    private let maxReconnectInterval: TimeInterval

    init(
        profile: ColimaProfile,
        status: ColimaStatusDetail,
        kubernetesProvider: KubernetesResourceProviding = LiveKubernetesResourceService(),
        streamingRunner: StreamingProcessRunning = LiveStreamingProcessRunner(),
        toolLocator: ToolLocator = LiveToolLocator(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executionMode: LiveColimaCLI.ExecutionMode = .resolvedPath,
        maxReconnectInterval: TimeInterval = 30
    ) {
        self.profile = profile
        self.status = status
        self.kubernetesProvider = kubernetesProvider
        self.streamingRunner = streamingRunner
        self.toolLocator = toolLocator
        self.environment = environment
        self.executionMode = executionMode
        self.maxReconnectInterval = maxReconnectInterval
    }

    func events() -> AsyncThrowingStream<RuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Skip when Kubernetes is disabled.
                guard status.kubernetes.enabled || profile.kubernetes.enabled else {
                    continuation.yield(.connectionStateChanged(source: .kubernetes, state: .disconnected))
                    continuation.finish()
                    return
                }

                // Skip if kubectl is not installed.
                guard toolLocator.locate("kubectl") != nil else {
                    continuation.yield(.connectionStateChanged(source: .kubernetes, state: .failed(reason: "kubectl CLI not found")))
                    continuation.finish()
                    return
                }

                let context = status.kubernetes.context.nonEmpty ?? profile.kubernetes.context.nonEmpty

                var attempt = 0
                while !Task.isCancelled {
                    continuation.yield(.connectionStateChanged(source: .kubernetes, state: attempt == 0 ? .connecting : .reconnecting(attempt: attempt)))

                    // Bootstrap: full k8s snapshot.
                    do {
                        let snapshot = try await kubernetesProvider.snapshot(context: context)
                        let slice = KubernetesResourceSnapshotSlice(
                            context: snapshot.context,
                            nodes: snapshot.nodes,
                            namespaces: snapshot.namespaces,
                            pods: snapshot.pods,
                            services: snapshot.services,
                            deployments: snapshot.deployments,
                            metrics: snapshot.metrics
                        )
                        continuation.yield(.snapshotReplaced(source: .kubernetes, docker: nil, kubernetes: slice))
                        continuation.yield(.connectionStateChanged(source: .kubernetes, state: .connected))
                        attempt = 0
                    } catch {
                        continuation.yield(.issue(BackendIssue(
                            severity: .warning,
                            source: .kubernetes,
                            title: "Kubernetes bootstrap failed",
                            message: error.localizedDescription
                        )))
                    }

                    // Run a pod watch as the primary trigger. On any watch event,
                    // re-snapshot the full k8s state and publish SnapshotReplaced.
                    do {
                        let request = try buildWatchRequest(resource: "pods", context: context)
                        let stream = streamingRunner.run(request, cancellation: nil)
                        for try await event in stream {
                            if Task.isCancelled { break }
                            switch event {
                            case .chunk(let chunk):
                                handleWatchChunk(chunk, context: context, continuation: continuation)
                            case .result:
                                break
                            }
                        }
                    } catch is CancellationError {
                        continuation.finish()
                        return
                    } catch {
                        continuation.yield(.issue(BackendIssue(
                            severity: .warning,
                            source: .kubernetes,
                            title: "Kubernetes watch stream ended",
                            message: error.localizedDescription
                        )))
                    }

                    if Task.isCancelled { break }

                    // Reconnect with backoff.
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

    private func handleWatchChunk(_ chunk: ProcessChunk, context: String?, continuation: AsyncThrowingStream<RuntimeEvent, Error>.Continuation) {
        let text = chunk.redactedString()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard JSONCommandParser.object(trimmed) != nil else {
                continuation.yield(.issue(BackendIssue(
                    severity: .warning,
                    source: .kubernetes,
                    title: "Dropped malformed Kubernetes watch line",
                    message: "A line from `kubectl get -w` was not valid JSON and was ignored."
                )))
                continue
            }
            // On any valid watch event, re-snapshot the full k8s state.
            // (Watch events contain the full object, but re-snapshotting ensures we
            // also pick up changes to nodes/services/deployments that aren't watched.)
            Task {
                do {
                    let snapshot = try await self.kubernetesProvider.snapshot(context: context)
                    let slice = KubernetesResourceSnapshotSlice(
                        context: snapshot.context,
                        nodes: snapshot.nodes,
                        namespaces: snapshot.namespaces,
                        pods: snapshot.pods,
                        services: snapshot.services,
                        deployments: snapshot.deployments,
                        metrics: snapshot.metrics
                    )
                    continuation.yield(.snapshotReplaced(source: .kubernetes, docker: nil, kubernetes: slice))
                } catch {
                    // Re-snapshot failed; the watch continues and next reconnect re-bootstraps.
                }
            }
        }
    }

    private func buildWatchRequest(resource: String, context: String?) throws -> ProcessRequest {
        do {
            let kubectlURL = try toolLocator.require("kubectl")
            let executableURL: URL
            let arguments: [String]
            switch executionMode {
            case .env:
                executableURL = URL(fileURLWithPath: "/usr/bin/env")
                arguments = ["kubectl"] + kubectlArguments(context: context, subcommand: ["get", resource, "--all-namespaces", "-w", "-o", "json"])
            case .resolvedPath:
                executableURL = kubectlURL
                arguments = kubectlArguments(context: context, subcommand: ["get", resource, "--all-namespaces", "-w", "-o", "json"])
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

    private func kubectlArguments(context: String?, subcommand: [String]) -> [String] {
        guard let context, !context.isEmpty else { return subcommand }
        return ["--context", context] + subcommand
    }
}
