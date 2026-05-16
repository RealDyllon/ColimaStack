import Foundation
import Testing
@testable import ColimaStack

struct SocketDockerResourceServiceTests {
    @Test func snapshotMapsEngineAPIFieldsToResourceModels() async throws {
        let client = FakeDockerEngineAPIClient(responses: [
            "/containers/json?all=1": .data("""
            [
              {
                "Id":"abc123",
                "Names":["/api"],
                "Image":"example/api:latest",
                "Command":"run-api",
                "Created":1700000000,
                "Ports":[{"IP":"0.0.0.0","PrivatePort":80,"PublicPort":8080,"Type":"tcp"}],
                "State":"running",
                "Status":"Up 2 minutes",
                "Labels":{"tier":"backend"}
              }
            ]
            """),
            "/images/json?digests=1": .data("""
            [
              {
                "Id":"sha256:image",
                "RepoTags":["example/api:latest"],
                "RepoDigests":["example/api@sha256:abc"],
                "Created":1700000000,
                "Size":42000000
              }
            ]
            """),
            "/volumes": .data("""
            {
              "Volumes":[{"Name":"api-data","Driver":"local","Scope":"local","Mountpoint":"/var/lib/docker/volumes/api-data","Labels":{"owner":"team"}}]
            }
            """),
            "/networks": .data("""
            [{"Id":"net123","Name":"bridge","Driver":"bridge","Scope":"local","Internal":false,"EnableIPv6":true}]
            """),
            "/system/df": .data("""
            {
              "Images":[{"Size":1000,"Containers":1},{"Size":2000,"Containers":0}],
              "Containers":[{"State":"running","SizeRw":500},{"State":"exited","SizeRw":700}],
              "Volumes":[{"Name":"api-data","UsageData":{"Size":4096,"RefCount":1}},{"Name":"cache","UsageData":{"Size":2048,"RefCount":0}}],
              "BuildCache":[{"Size":100,"InUse":true},{"Size":50,"InUse":false}]
            }
            """),
            "/containers/abc123/stats?stream=false": .data(statsJSON(id: "abc123", name: "/api", systemDelta: 5_000, cpuDelta: 200))
        ])
        let service = SocketDockerResourceService(clientFactory: { _ in client })

        let snapshot = try await service.snapshot(socketPath: "unix:///Users/me/.colima/default/docker.sock")

        #expect(snapshot.context == "colima")
        #expect(snapshot.containers.first?.name == "api")
        #expect(snapshot.containers.first?.labels == ["tier": "backend"])
        #expect(snapshot.containers.first?.portBindings == [
            DockerContainerResource.PortBinding(hostIP: "0.0.0.0", hostPort: 8080, containerPort: 80, proto: "tcp")
        ])
        #expect(snapshot.images.first?.repository == "example/api")
        #expect(snapshot.images.first?.tag == "latest")
        #expect(snapshot.images.first?.digest == "sha256:abc")
        #expect(snapshot.images.first?.createdAt == "2023-11-14 22:13:20 UTC")
        #expect(snapshot.volumes.first?.mountpoint == "/var/lib/docker/volumes/api-data")
        #expect(snapshot.networks.first?.ipv6Enabled == true)
        #expect(snapshot.diskUsage.map(\.type) == ["Images", "Containers", "Volumes", "Build Cache"])
        #expect(snapshot.stats.first?.name == "api")
        #expect(snapshot.stats.first?.cpuPercent == "8.00%")
        #expect(snapshot.stats.first?.memoryPercent == "6.25%")
        #expect(snapshot.stats.first?.pids == "9")
    }

    @Test func snapshotKeepsSuccessfulSectionsWhenSectionAndStatsRequestsFail() async throws {
        let client = FakeDockerEngineAPIClient(responses: emptyResponses().merging([
            "/containers/json?all=1": .data("""
            [
              {"Id":"live","Names":["/web"],"Image":"nginx","State":"running"},
              {"Id":"bad","Names":["/worker"],"Image":"busybox","State":"running"}
            ]
            """),
            "/networks": .failure(.httpStatus(500, "permission denied")),
            "/containers/live/stats?stream=false": .data(statsJSON(id: "live", name: "/web", systemDelta: 10_000, cpuDelta: 10)),
            "/containers/bad/stats?stream=false": .failure(.httpStatus(500, "stats failed"))
        ]) { _, new in new })
        let service = SocketDockerResourceService(clientFactory: { _ in client })

        let snapshot = try await service.snapshot(socketPath: "unix:///Users/me/.colima/dev/docker.sock")

        #expect(snapshot.context == "colima-dev")
        #expect(snapshot.containers.map(\.name) == ["web", "worker"])
        #expect(snapshot.networks.isEmpty)
        #expect(snapshot.stats.map(\.name) == ["web"])
        #expect(snapshot.issues.contains { issue in
            issue.title == "List Docker networks"
                && issue.source == .docker
                && issue.severity == .warning
                && issue.message.contains("permission denied")
        })
        #expect(snapshot.issues.contains { issue in
            issue.title == "Read Docker container stats"
                && issue.source == .metrics
                && issue.severity == .warning
                && issue.message.contains("worker")
        })
    }

    @Test func zeroSystemDeltaReportsZeroCPUPercent() async throws {
        let client = FakeDockerEngineAPIClient(responses: emptyResponses().merging([
            "/containers/json?all=1": .data(#"[{"Id":"idle","Names":["/idle"],"State":"running"}]"#),
            "/containers/idle/stats?stream=false": .data(statsJSON(id: "idle", name: "/idle", systemDelta: 0, cpuDelta: 100))
        ]) { _, new in new })
        let service = SocketDockerResourceService(clientFactory: { _ in client })

        let snapshot = try await service.snapshot(socketPath: "unix:///Users/me/.colima/default/docker.sock")

        #expect(snapshot.stats.first?.cpuPercent == "0.00%")
    }

    @Test func contextNameDerivesDefaultAndNamedProfilesFromSocketPath() async throws {
        let client = FakeDockerEngineAPIClient(responses: emptyResponses())
        let service = SocketDockerResourceService(clientFactory: { _ in client })

        let defaultSnapshot = try await service.snapshot(socketPath: "unix:///Users/me/.colima/default/docker.sock")
        let devSnapshot = try await service.snapshot(socketPath: "unix:///Users/me/.colima/dev/docker.sock")

        #expect(defaultSnapshot.context == "colima")
        #expect(devSnapshot.context == "colima-dev")
    }

    @Test func emptySocketPathFailsWithoutCreatingClient() async {
        let client = FakeDockerEngineAPIClient(responses: emptyResponses())
        let probe = ClientFactoryProbe(client: client)
        let service = SocketDockerResourceService(clientFactory: { path in probe.makeClient(socketPath: path) })

        let state = await service.loadSnapshot(socketPath: "")

        guard case let .failed(issue, lastValue) = state else {
            Issue.record("Expected failed load state")
            return
        }
        #expect(lastValue == nil)
        #expect(issue.source == .docker)
        #expect(issue.message.contains("empty"))
        #expect(probe.callCount() == 0)
        #expect(await client.requests().isEmpty)
    }
}

private actor FakeDockerEngineAPIClient: DockerEngineAPIClient {
    enum Response: Sendable {
        case data(String)
        case failure(DockerUDSClientError)
    }

    private let responses: [String: Response]
    private var requestedKeys: [String] = []

    init(responses: [String: Response]) {
        self.responses = responses
    }

    func get(path: String, queryItems: [DockerUDSQueryItem]) async throws -> Data {
        let key = Self.key(path: path, queryItems: queryItems)
        requestedKeys.append(key)
        switch responses[key] {
        case let .data(json):
            return Data(json.utf8)
        case let .failure(error):
            throw error
        case .none:
            throw DockerUDSClientError.httpStatus(404, "No fake response for \(key)")
        }
    }

    func requests() -> [String] {
        requestedKeys
    }

    private nonisolated static func key(path: String, queryItems: [DockerUDSQueryItem]) -> String {
        guard !queryItems.isEmpty else { return path }
        return path + "?" + queryItems.map { "\($0.name)=\($0.value)" }.joined(separator: "&")
    }
}

private final class ClientFactoryProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let client: any DockerEngineAPIClient
    private var calls = 0

    init(client: any DockerEngineAPIClient) {
        self.client = client
    }

    func makeClient(socketPath: String) -> any DockerEngineAPIClient {
        lock.lock()
        calls += 1
        lock.unlock()
        return client
    }

    func callCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}

private func emptyResponses() -> [String: FakeDockerEngineAPIClient.Response] {
    [
        "/containers/json?all=1": .data("[]"),
        "/images/json?digests=1": .data("[]"),
        "/volumes": .data(#"{"Volumes":[]}"#),
        "/networks": .data("[]"),
        "/system/df": .data(#"{"Images":[],"Containers":[],"Volumes":[],"BuildCache":[]}"#)
    ]
}

private func statsJSON(id: String, name: String, systemDelta: UInt64, cpuDelta: UInt64) -> String {
    """
    {
      "id":"\(id)",
      "name":"\(name)",
      "cpu_stats":{
        "cpu_usage":{"total_usage":\(1_000 + cpuDelta),"percpu_usage":[1,2]},
        "system_cpu_usage":\(5_000 + systemDelta),
        "online_cpus":2
      },
      "precpu_stats":{
        "cpu_usage":{"total_usage":1000,"percpu_usage":[1,2]},
        "system_cpu_usage":5000,
        "online_cpus":2
      },
      "memory_stats":{"usage":64000000,"limit":1024000000},
      "networks":{"eth0":{"rx_bytes":1000,"tx_bytes":2000}},
      "blkio_stats":{"io_service_bytes_recursive":[{"op":"Read","value":3000},{"op":"Write","value":4000}]},
      "pids_stats":{"current":9}
    }
    """
}
