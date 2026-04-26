import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct DockerResourceServiceTests {
    @Test func snapshotBuildsExplicitContextArgumentsForEveryDockerCommand() async throws {
        let runner = FakeCommandRunProvider(outputs: [
            "Read active Docker context": .success("colima-dev\n"),
            "List Docker containers": .success(#"{"ID":"abc123","Names":"api","Image":"example/api:latest","State":"running","Labels":"tier=backend,owner=team"}"#),
            "List Docker images": .success(#"{"ID":"sha256:image","Repository":"example/api","Tag":"latest","Digest":"sha256:deadbeef","Size":"42MB"}"#),
            "List Docker volumes": .success(#"{"Name":"api-data","Driver":"local","Scope":"local","Mountpoint":"/var/lib/docker/volumes/api-data"}"#),
            "List Docker networks": .success(#"{"ID":"net123","Name":"bridge","Driver":"bridge","Scope":"local","Internal":"false","IPv6":"true"}"#),
            "Read Docker container stats": .success(#"{"Container":"abc123","Name":"api","CPUPerc":"1.25%","MemUsage":"64MiB / 1GiB","MemPerc":"6.25%","NetIO":"1kB / 2kB","BlockIO":"3kB / 4kB","PIDs":"9"}"#),
            "Read Docker disk usage": .success(#"{"Type":"Images","TotalCount":"3","Active":"1","Size":"1.2GB","Reclaimable":"500MB (41%)"}"#)
        ])
        let service = LiveDockerResourceService(commandRunner: runner)

        let snapshot = try await service.snapshot(context: "colima-dev")

        #expect(snapshot.context == "colima-dev")
        #expect(snapshot.containers.first?.id == "abc123")
        #expect(snapshot.containers.first?.labels == ["tier": "backend", "owner": "team"])
        #expect(snapshot.images.first?.displayName == "example/api:latest")
        #expect(snapshot.volumes.first?.mountpoint == "/var/lib/docker/volumes/api-data")
        #expect(snapshot.networks.first?.ipv6Enabled == true)
        #expect(snapshot.stats.first?.pids == "9")
        #expect(snapshot.diskUsage.first?.type == "Images")
        #expect(runner.requests.map(\.arguments) == [
            ["--context", "colima-dev", "context", "show"],
            ["--context", "colima-dev", "ps", "--all", "--no-trunc", "--format", "{{json .}}"],
            ["--context", "colima-dev", "images", "--digests", "--no-trunc", "--format", "{{json .}}"],
            ["--context", "colima-dev", "volume", "ls", "--format", "{{json .}}"],
            ["--context", "colima-dev", "network", "ls", "--no-trunc", "--format", "{{json .}}"],
            ["--context", "colima-dev", "stats", "--no-stream", "--format", "{{json .}}"],
            ["--context", "colima-dev", "system", "df", "--format", "{{json .}}"]
        ])
        #expect(runner.requests.allSatisfy { $0.toolName == "docker" && $0.timeout == 15 })
    }

    @Test func snapshotKeepsSuccessfulSectionsWhenOneDockerCommandFails() async throws {
        let runner = FakeCommandRunProvider(outputs: [
            "Read active Docker context": .success("colima\n"),
            "List Docker containers": .success("""
            {"ID":"live","Names":"web","Image":"nginx","State":"running"}
            {"ID":"dead","Names":"worker","Image":"busybox","State":"dead"}
            """),
            "List Docker images": .success(#"{"ID":"sha256:nginx","Repository":"nginx","Tag":"latest"}"#),
            "List Docker volumes": .success(#"{"Name":"cache","Driver":"local"}"#),
            "List Docker networks": .failure(status: 1, stdout: "", stderr: "permission denied"),
            "Read Docker container stats": .success(#"{"Container":"live","Name":"web","CPUPerc":"0.1%"}"#),
            "Read Docker disk usage": .success(#"{"Type":"Build Cache","TotalCount":"2","Active":"0"}"#)
        ])
        let service = LiveDockerResourceService(commandRunner: runner)

        let snapshot = try await service.snapshot(context: nil)

        #expect(snapshot.context == "colima")
        #expect(snapshot.containers.map(\.name) == ["web", "worker"])
        #expect(snapshot.images.map(\.repository) == ["nginx"])
        #expect(snapshot.volumes.map(\.name) == ["cache"])
        #expect(snapshot.networks.isEmpty)
        #expect(snapshot.stats.map(\.name) == ["web"])
        #expect(snapshot.diskUsage.map(\.type) == ["Build Cache"])
        #expect(snapshot.commandRuns.count == 7)
        #expect(snapshot.issues.contains { issue in
            issue.title == "List Docker networks"
                && issue.source == .docker
                && issue.severity == .warning
                && issue.message == "permission denied"
                && issue.command == "/usr/bin/env network ls --no-trunc --format {{json .}}"
        })
        #expect(snapshot.issues.contains { issue in
            issue.title == "Dead Docker containers detected"
                && issue.source == .docker
                && issue.severity == .warning
        })
    }

    @Test func snapshotRecordsRunnerThrowAsDockerIssueAndContinues() async throws {
        let runner = FakeCommandRunProvider(errorPurposes: ["Read active Docker context"])
        let service = LiveDockerResourceService(commandRunner: runner)

        let snapshot = try await service.snapshot(context: "colima")

        #expect(snapshot.context == "colima")
        #expect(snapshot.commandRuns.count == 6)
        #expect(snapshot.issues.contains { issue in
            issue.title == "Read active Docker context"
                && issue.source == .docker
                && issue.severity == .error
                && issue.message.contains("boom")
                && issue.recoverySuggestion == "Verify the Docker CLI is installed and reachable from PATH."
        })
    }

    @Test func malformedJSONLinesProduceAnIssueInsteadOfBeingSilentlyDropped() async throws {
        let runner = FakeCommandRunProvider(outputs: [
            "Read active Docker context": .success("colima\n"),
            "List Docker containers": .success("""
            {"ID":"valid","Names":"web","Image":"nginx","State":"running"}
            {"ID":
            {"ID":"also-valid","Names":"api","Image":"busybox","State":"exited"}
            """),
            "List Docker images": .success("not-json"),
            "List Docker volumes": .success(#"{"Driver":"local"}"#),
            "List Docker networks": .success(#"{"Name":"bridge","Driver":"bridge"}"#),
            "Read Docker container stats": .success(#"{"Name":"web","CPUPerc":"1%"}"#),
            "Read Docker disk usage": .success(#"{"TotalCount":"3"}"#)
        ])
        let service = LiveDockerResourceService(commandRunner: runner)

        let snapshot = try await service.snapshot(context: nil)

        #expect(snapshot.containers.map(\.id) == ["valid", "also-valid"])
        #expect(snapshot.images.isEmpty)
        #expect(snapshot.volumes.isEmpty)
        #expect(snapshot.networks.map(\.id) == ["bridge"])
        #expect(snapshot.stats.map(\.id) == ["web"])
        #expect(snapshot.diskUsage.isEmpty)
        #expect(snapshot.issues.contains { issue in
            issue.title == "List Docker containers"
                && issue.source == .docker
                && issue.message.contains("malformed JSON")
        })
        #expect(snapshot.issues.contains { issue in
            issue.title == "List Docker images"
                && issue.source == .docker
                && issue.message.contains("malformed JSON")
        })
        #expect(snapshot.issues.contains { issue in
            issue.title == "List Docker volumes"
                && issue.source == .docker
                && issue.message.contains("missing required fields")
        })
        #expect(snapshot.issues.contains { issue in
            issue.title == "Read Docker disk usage"
                && issue.source == .metrics
                && issue.message.contains("missing required fields")
        })
    }
}

private final class FakeCommandRunProvider: CommandRunProviding {
    enum Output {
        case success(String)
        case failure(status: Int32, stdout: String, stderr: String)
    }

    private let outputs: [String: Output]
    private let errorPurposes: Set<String>
    private(set) var requests: [ManagedCommandRequest] = []

    init(outputs: [String: Output] = [:], errorPurposes: Set<String> = []) {
        self.outputs = outputs
        self.errorPurposes = errorPurposes
    }

    func run(_ request: ManagedCommandRequest) async throws -> ManagedCommandRun {
        requests.append(request)
        if errorPurposes.contains(request.purpose) {
            throw DockerResourceTestError(message: "boom for \(request.purpose)")
        }
        switch outputs[request.purpose] ?? .success("") {
        case let .success(stdout):
            return run(for: request, status: 0, stdout: stdout, stderr: "")
        case let .failure(status, stdout, stderr):
            return run(for: request, status: status, stdout: stdout, stderr: stderr)
        }
    }

    private func run(for request: ManagedCommandRequest, status: Int32, stdout: String, stderr: String) -> ManagedCommandRun {
        ManagedCommandRun(
            request: request,
            executablePath: "/usr/bin/env",
            launchedAt: Date(),
            duration: 0,
            terminationStatus: status,
            standardOutput: stdout,
            standardError: stderr
        )
    }
}

private struct DockerResourceTestError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
