import Foundation

nonisolated protocol AsyncProcessRunning {
    func run(_ request: ProcessRequest) async throws -> ProcessResult
}

nonisolated struct AsyncProcessRunnerAdapter: AsyncProcessRunning {
    private let processRunner: ProcessRunner

    init(processRunner: ProcessRunner = LiveProcessRunner()) {
        self.processRunner = processRunner
    }

    func run(_ request: ProcessRequest) async throws -> ProcessResult {
        if let cancellableRunner = processRunner as? CancellableProcessRunner {
            let cancellation = ProcessCancellation()
            return try await withTaskCancellationHandler {
                try await Task.detached(priority: .utility) {
                    try cancellableRunner.run(request, cancellation: cancellation)
                }.value
            } onCancel: {
                cancellation.cancel()
            }
        }

        return try await Task.detached(priority: .utility) {
            try processRunner.run(request)
        }.value
    }
}

nonisolated protocol CommandRunProviding {
    func run(_ request: ManagedCommandRequest) async throws -> ManagedCommandRun
}

nonisolated struct LiveCommandRunService: CommandRunProviding {
    private static let forwardedColimaEnvironmentKeys = [
        "COLIMA_HOME"
    ]

    private static let forwardedEnvironmentKeys = [
        "KUBECONFIG",
        "DOCKER_HOST",
        "DOCKER_CONTEXT",
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "NO_PROXY",
        "ALL_PROXY",
        "http_proxy",
        "https_proxy",
        "no_proxy",
        "all_proxy"
    ]

    private let processRunner: AsyncProcessRunning
    private let toolLocator: ToolLocator
    private let environment: [String: String]
    private let executionMode: LiveColimaCLI.ExecutionMode

    init(
        processRunner: AsyncProcessRunning = AsyncProcessRunnerAdapter(),
        toolLocator: ToolLocator = LiveToolLocator(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executionMode: LiveColimaCLI.ExecutionMode = .resolvedPath
    ) {
        self.processRunner = processRunner
        self.toolLocator = toolLocator
        self.environment = environment
        self.executionMode = executionMode
    }

    func run(_ request: ManagedCommandRequest) async throws -> ManagedCommandRun {
        do {
            let toolURL = try toolLocator.require(request.toolName)
            let executableURL: URL
            let arguments: [String]
            switch executionMode {
            case .env:
                executableURL = URL(fileURLWithPath: "/usr/bin/env")
                arguments = [request.toolName] + request.arguments
            case .resolvedPath:
                executableURL = toolURL
                arguments = request.arguments
            }

            let processRequest = ProcessRequest(
                executableURL: executableURL,
                arguments: arguments,
                environment: environmentOverrides(request.environment),
                currentDirectoryURL: request.currentDirectoryPath.map(URL.init(fileURLWithPath:)),
                standardInput: request.standardInput,
                timeout: request.timeout
            )
            let result = try await processRunner.run(processRequest)
            var storedRequest = request
            storedRequest.arguments = EnvironmentRedactor.redacted(result.arguments.dropFirstToolIfNeeded(toolName: request.toolName, executionMode: executionMode))
            storedRequest.environment = EnvironmentRedactor.redacted(result.environment)
            return ManagedCommandRun(
                request: storedRequest,
                executablePath: result.executableURL.path,
                launchedAt: result.launchedAt,
                duration: result.duration,
                terminationStatus: result.terminationStatus,
                standardOutput: EnvironmentRedactor.redacted(result.standardOutput),
                standardError: EnvironmentRedactor.redacted(result.standardError)
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

    private func environmentOverrides(_ overrides: [String: String]) -> [String: String] {
        let searchPath = toolLocator.searchPaths().joined(separator: ":")
        var merged = overrides
        if !searchPath.isEmpty {
            merged["PATH"] = searchPath
        }
        for key in Self.forwardedColimaEnvironmentKeys where merged[key] == nil {
            if let value = environment[key], !value.isEmpty {
                merged[key] = value
            }
        }
        for key in Self.forwardedEnvironmentKeys where merged[key] == nil {
            if let value = environment[key], !value.isEmpty {
                merged[key] = value
            }
        }
        return merged
    }
}

nonisolated private extension Array where Element == String {
    func dropFirstToolIfNeeded(toolName: String, executionMode: LiveColimaCLI.ExecutionMode) -> [String] {
        guard case .env = executionMode, first == toolName else {
            return self
        }
        return Array(dropFirst())
    }
}
