import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct KubernetesResourceServiceTests {
    @Test func explicitContextIsUsedForEveryKubectlReadAndReportedInSnapshot() async throws {
        let runner = FakeKubernetesCommandRunner(results: [
            "--context colima-dev config current-context": .success(.kubectl(arguments: ["--context", "colima-dev", "config", "current-context"], stdout: "desktop-linux\n")),
            "--context colima-dev get nodes -o json": .success(.kubectl(arguments: ["--context", "colima-dev", "get", "nodes", "-o", "json"], stdout: Self.listJSON())),
            "--context colima-dev get namespaces -o json": .success(.kubectl(arguments: ["--context", "colima-dev", "get", "namespaces", "-o", "json"], stdout: Self.listJSON())),
            "--context colima-dev get pods --all-namespaces -o json": .success(.kubectl(arguments: ["--context", "colima-dev", "get", "pods", "--all-namespaces", "-o", "json"], stdout: Self.listJSON())),
            "--context colima-dev get services --all-namespaces -o json": .success(.kubectl(arguments: ["--context", "colima-dev", "get", "services", "--all-namespaces", "-o", "json"], stdout: Self.listJSON())),
            "--context colima-dev get deployments --all-namespaces -o json": .success(.kubectl(arguments: ["--context", "colima-dev", "get", "deployments", "--all-namespaces", "-o", "json"], stdout: Self.listJSON())),
            "--context colima-dev top nodes --no-headers": .success(.kubectl(arguments: ["--context", "colima-dev", "top", "nodes", "--no-headers"])),
            "--context colima-dev top pods --all-namespaces --no-headers": .success(.kubectl(arguments: ["--context", "colima-dev", "top", "pods", "--all-namespaces", "--no-headers"]))
        ])
        let service = LiveKubernetesResourceService(commandRunner: runner)

        let snapshot = try await service.snapshot(context: "colima-dev")

        #expect(snapshot.context == "colima-dev")
        #expect(runner.requests.contains { $0.arguments == ["--context", "colima-dev", "config", "current-context"] })
        #expect(runner.requests.allSatisfy { $0.arguments.starts(with: ["--context", "colima-dev"]) })
    }

    @Test func loadSnapshotFailsWhenClusterIsUnavailableForEveryKubectlCommand() async {
        let runner = FakeKubernetesCommandRunner(error: TestError(message: "kubectl: command not found"))
        let service = LiveKubernetesResourceService(commandRunner: runner)

        let state = await service.loadSnapshot(context: "colima-dev")

        guard case let .failed(issue, lastValue) = state else {
            Issue.record("Expected a failed load state when every kubectl invocation throws.")
            return
        }
        #expect(issue.source == .kubernetes)
        #expect(issue.severity == .error)
        #expect(issue.message.contains("kubectl: command not found"))
        #expect(lastValue == nil)
    }

    @Test func parsesWorkloadsServicesAndMetricsFromKubectlJSON() async throws {
        let runner = FakeKubernetesCommandRunner(results: [
            "config current-context": .success(.kubectl(arguments: ["config", "current-context"], stdout: "colima\n")),
            "get nodes -o json": .success(.kubectl(arguments: ["get", "nodes", "-o", "json"], stdout: Self.listJSON("""
            {
              "metadata": {
                "name": "colima",
                "uid": "node-1",
                "labels": {"node-role.kubernetes.io/control-plane": ""}
              },
              "status": {
                "nodeInfo": {"kubeletVersion": "v1.30.4+k3s1"},
                "allocatable": {"cpu": "4", "memory": "8Gi"},
                "addresses": [{"type": "InternalIP", "address": "192.168.5.15"}],
                "conditions": [{"type": "Ready", "status": "True"}]
              }
            }
            """))),
            "get namespaces -o json": .success(.kubectl(arguments: ["get", "namespaces", "-o", "json"], stdout: Self.listJSON("""
            {"metadata": {"name": "default", "uid": "ns-1"}, "status": {"phase": "Active"}}
            """))),
            "get pods --all-namespaces -o json": .success(.kubectl(arguments: ["get", "pods", "--all-namespaces", "-o", "json"], stdout: Self.listJSON("""
            {
              "metadata": {"name": "api-7c9", "namespace": "default", "uid": "pod-1"},
              "spec": {"nodeName": "colima"},
              "status": {
                "phase": "Running",
                "podIP": "10.42.0.8",
                "hostIP": "192.168.5.15",
                "containerStatuses": [{"name": "api", "image": "example/api:v1", "ready": true, "restartCount": 2, "state": {"running": {}}}]
              }
            }
            """))),
            "get services --all-namespaces -o json": .success(.kubectl(arguments: ["get", "services", "--all-namespaces", "-o", "json"], stdout: Self.listJSON("""
            {
              "metadata": {"name": "api", "namespace": "default", "uid": "svc-1"},
              "spec": {
                "type": "LoadBalancer",
                "clusterIP": "10.43.12.3",
                "externalIPs": ["192.168.5.20"],
                "ports": [{"name": "http", "port": 80, "protocol": "TCP"}]
              }
            }
            """))),
            "get deployments --all-namespaces -o json": .success(.kubectl(arguments: ["get", "deployments", "--all-namespaces", "-o", "json"], stdout: Self.listJSON("""
            {
              "metadata": {"name": "api", "namespace": "default", "uid": "deploy-1"},
              "spec": {"replicas": 3},
              "status": {"readyReplicas": 3, "availableReplicas": 3, "updatedReplicas": 3}
            }
            """))),
            "top nodes --no-headers": .success(.kubectl(arguments: ["top", "nodes", "--no-headers"], stdout: "colima 120m 512Mi\n")),
            "top pods --all-namespaces --no-headers": .success(.kubectl(arguments: ["top", "pods", "--all-namespaces", "--no-headers"], stdout: "default api-7c9 40m 128Mi\n"))
        ])
        let service = LiveKubernetesResourceService(commandRunner: runner)

        let snapshot = try await service.snapshot(context: nil)

        #expect(snapshot.nodes.first?.metadata.name == "colima")
        #expect(snapshot.nodes.first?.roles == ["control-plane"])
        #expect(snapshot.nodes.first?.health == .healthy)
        #expect(snapshot.namespaces.first?.phase == "Active")
        #expect(snapshot.pods.first?.containers.first?.restartCount == 2)
        #expect(snapshot.pods.first?.health == .healthy)
        #expect(snapshot.services.first?.ports == ["http/80/TCP"])
        #expect(snapshot.services.first?.externalIPs == ["192.168.5.20"])
        #expect(snapshot.deployments.first?.health == .healthy)
        #expect(snapshot.metrics.map(\.id) == ["node/colima", "pod/default/api-7c9"])
        #expect(snapshot.issues.isEmpty)
    }

    @Test func partialFailuresKeepSuccessfulResourcesAndRecordCommandIssues() async throws {
        let runner = FakeKubernetesCommandRunner(results: [
            "config current-context": .success(.kubectl(arguments: ["config", "current-context"], stdout: "colima\n")),
            "get nodes -o json": .success(.kubectl(arguments: ["get", "nodes", "-o", "json"], stdout: Self.listJSON())),
            "get namespaces -o json": .success(.kubectl(arguments: ["get", "namespaces", "-o", "json"], stdout: Self.listJSON())),
            "get pods --all-namespaces -o json": .success(.kubectl(arguments: ["get", "pods", "--all-namespaces", "-o", "json"], stdout: Self.listJSON("""
            {"metadata": {"name": "api", "namespace": "default"}, "status": {"phase": "Running", "containerStatuses": [{"name": "api", "ready": true}]}}
            """))),
            "get services --all-namespaces -o json": .success(.kubectl(arguments: ["get", "services", "--all-namespaces", "-o", "json"], status: 1, stderr: "Unable to connect to the server")),
            "get deployments --all-namespaces -o json": .success(.kubectl(arguments: ["get", "deployments", "--all-namespaces", "-o", "json"], stdout: Self.listJSON())),
            "top nodes --no-headers": .success(.kubectl(arguments: ["top", "nodes", "--no-headers"])),
            "top pods --all-namespaces --no-headers": .success(.kubectl(arguments: ["top", "pods", "--all-namespaces", "--no-headers"]))
        ])
        let service = LiveKubernetesResourceService(commandRunner: runner)

        let snapshot = try await service.snapshot(context: nil)

        #expect(snapshot.pods.map(\.metadata.name) == ["api"])
        #expect(snapshot.services.isEmpty)
        #expect(snapshot.commandRuns.count == 8)
        #expect(snapshot.issues.contains { issue in
            issue.title == "List Kubernetes services" &&
            issue.severity == .warning &&
            issue.message.contains("Unable to connect")
        })
    }

    @Test func invalidJSONAndInvalidItemsCreateParseIssues() async throws {
        let runner = FakeKubernetesCommandRunner(results: [
            "config current-context": .success(.kubectl(arguments: ["config", "current-context"], stdout: "colima\n")),
            "get nodes -o json": .success(.kubectl(arguments: ["get", "nodes", "-o", "json"], stdout: "not json")),
            "get namespaces -o json": .success(.kubectl(arguments: ["get", "namespaces", "-o", "json"], stdout: Self.listJSON())),
            "get pods --all-namespaces -o json": .success(.kubectl(arguments: ["get", "pods", "--all-namespaces", "-o", "json"], stdout: Self.listJSON("""
            {"metadata": {"namespace": "default"}, "status": {"phase": "Running"}}
            """))),
            "get services --all-namespaces -o json": .success(.kubectl(arguments: ["get", "services", "--all-namespaces", "-o", "json"], stdout: Self.listJSON("""
            {"metadata": {"name": "api", "namespace": "default"}, "spec": {"ports": "bad-shape"}}
            """))),
            "get deployments --all-namespaces -o json": .success(.kubectl(arguments: ["get", "deployments", "--all-namespaces", "-o", "json"], stdout: Self.listJSON("""
            {"metadata": {"name": "api", "namespace": "default"}, "spec": {"replicas": "not-a-number"}, "status": {"readyReplicas": 1}}
            """))),
            "top nodes --no-headers": .success(.kubectl(arguments: ["top", "nodes", "--no-headers"])),
            "top pods --all-namespaces --no-headers": .success(.kubectl(arguments: ["top", "pods", "--all-namespaces", "--no-headers"]))
        ])
        let service = LiveKubernetesResourceService(commandRunner: runner)

        let snapshot = try await service.snapshot(context: nil)

        #expect(snapshot.nodes.isEmpty)
        #expect(snapshot.pods.isEmpty)
        #expect(snapshot.services.first?.ports == [])
        #expect(snapshot.deployments.first?.desiredReplicas == 0)
        #expect(snapshot.issues.contains { $0.title == "Unable to parse Kubernetes output" })
        #expect(snapshot.issues.contains { issue in
            issue.title == "Invalid Kubernetes resource item" &&
            issue.message.contains("metadata.name")
        })
    }

    nonisolated fileprivate static func listJSON(_ items: String...) -> String {
        """
        {"items":[\(items.joined(separator: ","))]}
        """
    }
}

private final class FakeKubernetesCommandRunner: CommandRunProviding {
    private(set) var requests: [ManagedCommandRequest] = []
    private var results: [String: Result<ManagedCommandRun, Error>]
    private let error: Error?

    init(results: [String: Result<ManagedCommandRun, Error>] = [:], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    func run(_ request: ManagedCommandRequest) async throws -> ManagedCommandRun {
        requests.append(request)
        if let error {
            throw error
        }

        let key = request.arguments.joined(separator: " ")
        if let result = results[key] {
            return try result.get()
        }
        return .kubectl(arguments: request.arguments, stdout: KubernetesResourceServiceTests.listJSON())
    }
}

private extension ManagedCommandRun {
    static func kubectl(
        arguments: [String],
        status: Int32 = 0,
        stdout: String = "",
        stderr: String = ""
    ) -> ManagedCommandRun {
        ManagedCommandRun(
            request: ManagedCommandRequest(toolName: "kubectl", arguments: arguments, purpose: ""),
            executablePath: "/usr/bin/env",
            launchedAt: Date(timeIntervalSince1970: 0),
            duration: 0.01,
            terminationStatus: status,
            standardOutput: stdout,
            standardError: stderr
        )
    }
}
