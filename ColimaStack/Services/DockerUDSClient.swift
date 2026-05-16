import Foundation
@preconcurrency import Network

nonisolated struct DockerUDSQueryItem: Hashable, Sendable {
    var name: String
    var value: String
}

nonisolated protocol DockerEngineAPIClient: Sendable {
    func get(path: String, queryItems: [DockerUDSQueryItem]) async throws -> Data
}

nonisolated extension DockerEngineAPIClient {
    func get(path: String) async throws -> Data {
        try await get(path: path, queryItems: [])
    }

    func decode<Value: Decodable>(
        _ type: Value.Type,
        path: String,
        queryItems: [DockerUDSQueryItem] = [],
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Value {
        let data = try await get(path: path, queryItems: queryItems)
        return try decoder.decode(type, from: data)
    }
}

nonisolated protocol DockerUDSTransport: Sendable {
    func send(request: Data, socketPath: String, timeout: TimeInterval) async throws -> Data
}

nonisolated enum DockerUDSClientError: LocalizedError, Sendable, Equatable {
    case missingSocketPath(String)
    case connectionFailed(String)
    case timeout(TimeInterval)
    case invalidResponse(String)
    case invalidUTF8Response
    case httpStatus(Int, String)
    case malformedChunkedBody(String)

    var errorDescription: String? {
        switch self {
        case let .missingSocketPath(path):
            return path.isEmpty
                ? "Docker socket path is empty."
                : "Docker socket does not exist at \(path)."
        case let .connectionFailed(message):
            return "Docker socket connection failed: \(message)"
        case let .timeout(timeout):
            return "Docker socket request timed out after \(String(format: "%.1f", timeout))s."
        case let .invalidResponse(message):
            return "Docker daemon returned an invalid HTTP response: \(message)"
        case .invalidUTF8Response:
            return "Docker daemon returned response headers that are not valid UTF-8."
        case let .httpStatus(status, body):
            return body.isEmpty
                ? "Docker daemon returned HTTP \(status)."
                : "Docker daemon returned HTTP \(status): \(body)"
        case let .malformedChunkedBody(message):
            return "Docker daemon returned malformed chunked response data: \(message)"
        }
    }
}

nonisolated struct DockerUDSClient: DockerEngineAPIClient {
    var socketPath: String
    var timeout: TimeInterval

    private let transport: any DockerUDSTransport

    init(
        socketPath: String,
        timeout: TimeInterval = 8,
        transport: any DockerUDSTransport = NetworkDockerUDSTransport()
    ) {
        self.socketPath = socketPath
        self.timeout = timeout
        self.transport = transport
    }

    func get(path: String, queryItems: [DockerUDSQueryItem] = []) async throws -> Data {
        let normalizedSocketPath = Self.normalizedSocketPath(socketPath)
        let request = try Self.request(path: path, queryItems: queryItems)
        let response = try await Self.withTimeout(seconds: timeout) {
            try await transport.send(request: request, socketPath: normalizedSocketPath, timeout: timeout)
        }
        return try Self.responseBody(from: response)
    }

    nonisolated static func normalizedSocketPath(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("unix://") else { return trimmed }
        return String(trimmed.dropFirst("unix://".count))
    }

    nonisolated static func request(path: String, queryItems: [DockerUDSQueryItem]) throws -> Data {
        let requestPath = Self.requestPath(path: path, queryItems: queryItems)
        let raw = "GET \(requestPath) HTTP/1.1\r\n"
            + "Host: docker\r\n"
            + "Accept: application/json\r\n"
            + "Connection: close\r\n"
            + "\r\n"
        guard let data = raw.data(using: .utf8) else {
            throw DockerUDSClientError.invalidUTF8Response
        }
        return data
    }

    nonisolated static func responseBody(from response: Data) throws -> Data {
        let headerTerminator = Data([13, 10, 13, 10])
        guard let headerRange = response.range(of: headerTerminator) else {
            throw DockerUDSClientError.invalidResponse("missing header terminator")
        }
        let headerData = response[..<headerRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw DockerUDSClientError.invalidUTF8Response
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let statusLine = lines.first, statusLine.hasPrefix("HTTP/") else {
            throw DockerUDSClientError.invalidResponse("missing HTTP status line")
        }
        let statusParts = statusLine.split(separator: " ", maxSplits: 2)
        guard statusParts.count >= 2, let status = Int(statusParts[1]) else {
            throw DockerUDSClientError.invalidResponse("invalid HTTP status line: \(statusLine)")
        }

        let headers = lines.dropFirst().reduce(into: [String: String]()) { result, line in
            guard let separator = line.firstIndex(of: ":") else { return }
            let name = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            result[name] = value
        }

        var body = Data(response[headerRange.upperBound...])
        if headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
            body = try decodeChunkedBody(body)
        } else if let rawLength = headers["content-length"], let length = Int(rawLength) {
            guard body.count >= length else {
                throw DockerUDSClientError.invalidResponse("body shorter than Content-Length")
            }
            body = Data(body.prefix(length))
        }

        guard (200..<300).contains(status) else {
            let bodyText = String(data: body, encoding: .utf8) ?? ""
            throw DockerUDSClientError.httpStatus(status, bodyText)
        }

        return body
    }

    nonisolated static func decodeChunkedBody(_ body: Data) throws -> Data {
        let bytes = [UInt8](body)
        var index = 0
        var decoded = Data()

        while index < bytes.count {
            guard let lineEnd = Self.crlfIndex(in: bytes, startingAt: index) else {
                throw DockerUDSClientError.malformedChunkedBody("missing chunk size terminator")
            }
            guard let sizeLine = String(bytes: bytes[index..<lineEnd], encoding: .utf8) else {
                throw DockerUDSClientError.invalidUTF8Response
            }
            let sizeToken = sizeLine
                .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let size = Int(sizeToken, radix: 16) else {
                throw DockerUDSClientError.malformedChunkedBody("invalid chunk size \(sizeLine)")
            }

            index = lineEnd + 2
            if size == 0 {
                return decoded
            }
            guard index + size <= bytes.count else {
                throw DockerUDSClientError.malformedChunkedBody("chunk body shorter than declared size")
            }
            decoded.append(contentsOf: bytes[index..<(index + size)])
            index += size
            guard index + 1 < bytes.count, bytes[index] == 13, bytes[index + 1] == 10 else {
                throw DockerUDSClientError.malformedChunkedBody("missing chunk body terminator")
            }
            index += 2
        }

        throw DockerUDSClientError.malformedChunkedBody("missing terminal zero-size chunk")
    }

    private nonisolated static func requestPath(path: String, queryItems: [DockerUDSQueryItem]) -> String {
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard !queryItems.isEmpty else { return normalizedPath }

        var components = URLComponents()
        components.path = normalizedPath
        components.queryItems = queryItems.map { URLQueryItem(name: $0.name, value: $0.value) }
        return components.string ?? normalizedPath
    }

    private nonisolated static func crlfIndex(in bytes: [UInt8], startingAt start: Int) -> Int? {
        guard start < bytes.count else { return nil }
        for index in start..<(bytes.count - 1) where bytes[index] == 13 && bytes[index + 1] == 10 {
            return index
        }
        return nil
    }

    private nonisolated static func withTimeout<Value: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let nanoseconds = UInt64(max(seconds, 0) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw DockerUDSClientError.timeout(seconds)
            }
            guard let value = try await group.next() else {
                throw DockerUDSClientError.invalidResponse("request did not produce a result")
            }
            group.cancelAll()
            return value
        }
    }
}

nonisolated struct NetworkDockerUDSTransport: DockerUDSTransport {
    func send(request: Data, socketPath: String, timeout: TimeInterval) async throws -> Data {
        _ = timeout
        guard !socketPath.isEmpty else {
            throw DockerUDSClientError.missingSocketPath(socketPath)
        }
        guard FileManager.default.fileExists(atPath: socketPath) else {
            throw DockerUDSClientError.missingSocketPath(socketPath)
        }

        let connection = NWConnection(to: .unix(path: socketPath), using: .tcp)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let queue = DispatchQueue(label: "app.colimastack.docker-uds-client")
                let state = DockerUDSConnectionState(connection: connection, continuation: continuation)

                connection.stateUpdateHandler = { connectionState in
                    switch connectionState {
                    case .ready:
                        connection.send(content: request, completion: .contentProcessed { error in
                            if let error {
                                state.fail(DockerUDSClientError.connectionFailed(error.localizedDescription))
                            } else {
                                Self.receive(connection: connection, state: state)
                            }
                        })
                    case let .failed(error):
                        state.fail(DockerUDSClientError.connectionFailed(error.localizedDescription))
                    case .cancelled:
                        break
                    default:
                        break
                    }
                }
                connection.start(queue: queue)
            }
        } onCancel: {
            connection.cancel()
        }
    }

    private nonisolated static func receive(connection: NWConnection, state: DockerUDSConnectionState) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                state.append(data)
            }
            if let error {
                state.fail(DockerUDSClientError.connectionFailed(error.localizedDescription))
            } else if isComplete {
                state.succeed()
            } else {
                Self.receive(connection: connection, state: state)
            }
        }
    }
}

private nonisolated final class DockerUDSConnectionState: @unchecked Sendable {
    private let connection: NWConnection
    private let continuation: CheckedContinuation<Data, Error>
    private let lock = NSLock()
    private var completed = false
    private var response = Data()

    init(connection: NWConnection, continuation: CheckedContinuation<Data, Error>) {
        self.connection = connection
        self.continuation = continuation
    }

    func append(_ data: Data) {
        lock.lock()
        response.append(data)
        lock.unlock()
    }

    func succeed() {
        complete { response in
            continuation.resume(returning: response)
        }
    }

    func fail(_ error: Error) {
        complete { _ in
            continuation.resume(throwing: error)
        }
    }

    private func complete(_ resume: (Data) -> Void) {
        let response: Data
        lock.lock()
        if completed {
            lock.unlock()
            return
        }
        completed = true
        response = self.response
        lock.unlock()

        connection.cancel()
        resume(response)
    }
}
