import Foundation
import Testing
@testable import ColimaStack

struct DockerUDSClientTests {
    @Test func getBuildsHTTPRequestAndReturnsContentLengthBody() async throws {
        let transport = FakeDockerUDSTransport(
            behavior: .response(httpResponse(body: #"{"ok":true}"#))
        )
        let client = DockerUDSClient(socketPath: "unix:///tmp/docker.sock", timeout: 1, transport: transport)

        let body = try await client.get(
            path: "/containers/json",
            queryItems: [DockerUDSQueryItem(name: "all", value: "1")]
        )

        #expect(String(data: body, encoding: .utf8) == #"{"ok":true}"#)
        let requests = await transport.requests()
        #expect(requests.map(\.socketPath) == ["/tmp/docker.sock"])
        let requestText = String(data: requests.first?.request ?? Data(), encoding: .utf8) ?? ""
        #expect(requestText.hasPrefix("GET /containers/json?all=1 HTTP/1.1\r\n"))
        #expect(requestText.contains("Host: docker\r\n"))
        #expect(requestText.contains("Connection: close\r\n"))
    }

    @Test func getThrowsForNonSuccessStatusWithResponseBody() async throws {
        let transport = FakeDockerUDSTransport(
            behavior: .response(httpResponse(status: 404, reason: "Not Found", body: "missing"))
        )
        let client = DockerUDSClient(socketPath: "/tmp/docker.sock", timeout: 1, transport: transport)

        do {
            _ = try await client.get(path: "/missing")
            Issue.record("Expected HTTP status error")
        } catch let error as DockerUDSClientError {
            #expect(error.localizedDescription.contains("HTTP 404"))
            #expect(error.localizedDescription.contains("missing"))
        }
    }

    @Test func getEnforcesTimeout() async throws {
        let transport = FakeDockerUDSTransport(
            behavior: .delay(seconds: 2, response: httpResponse(body: "{}"))
        )
        let client = DockerUDSClient(socketPath: "/tmp/docker.sock", timeout: 0.01, transport: transport)

        do {
            _ = try await client.get(path: "/slow")
            Issue.record("Expected timeout")
        } catch let error as DockerUDSClientError {
            #expect(error.localizedDescription.contains("timed out"))
        }
    }

    @Test func getReassemblesChunkedResponseBody() async throws {
        let raw = "HTTP/1.1 200 OK\r\n"
            + "Transfer-Encoding: chunked\r\n"
            + "\r\n"
            + "4\r\n"
            + "Wiki\r\n"
            + "5\r\n"
            + "pedia\r\n"
            + "0\r\n"
            + "\r\n"
        let transport = FakeDockerUDSTransport(behavior: .response(Data(raw.utf8)))
        let client = DockerUDSClient(socketPath: "/tmp/docker.sock", timeout: 1, transport: transport)

        let body = try await client.get(path: "/chunked")

        #expect(String(data: body, encoding: .utf8) == "Wikipedia")
    }
}

private actor FakeDockerUDSTransport: DockerUDSTransport {
    enum Behavior: Sendable {
        case response(Data)
        case delay(seconds: TimeInterval, response: Data)
        case failure(DockerUDSClientError)
    }

    private let behavior: Behavior
    private var sentRequests: [SentRequest] = []

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func send(request: Data, socketPath: String, timeout: TimeInterval) async throws -> Data {
        sentRequests.append(SentRequest(request: request, socketPath: socketPath, timeout: timeout))
        switch behavior {
        case let .response(data):
            return data
        case let .delay(seconds, data):
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return data
        case let .failure(error):
            throw error
        }
    }

    func requests() -> [SentRequest] {
        sentRequests
    }
}

private struct SentRequest: Sendable {
    var request: Data
    var socketPath: String
    var timeout: TimeInterval
}

private func httpResponse(status: Int = 200, reason: String = "OK", body: String) -> Data {
    let bodyData = Data(body.utf8)
    let headers = "HTTP/1.1 \(status) \(reason)\r\n"
        + "Content-Length: \(bodyData.count)\r\n"
        + "\r\n"
    var response = Data(headers.utf8)
    response.append(bodyData)
    return response
}
