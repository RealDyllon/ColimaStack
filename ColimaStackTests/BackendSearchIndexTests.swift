import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct BackendSearchIndexTests {
    @Test func includeStoppedFalseFiltersStoppedProfiles() {
        let running = Self.profile(named: "api", state: .running, rawSummary: "api running")
        let stopped = Self.profile(named: "old-api", state: .stopped, rawSummary: "old-api stopped")
        let index = BackendSearchIndexer().index(profiles: [running, stopped])

        let results = index.search(BackendSearchQuery(text: "api", includeStopped: false))

        #expect(results.map { $0.title } == ["api"])
    }

    @Test func exactTitleMatchesRankBeforeTokenOnlyMatches() {
        let profile = Self.profile(named: "frontend", rawSummary: "api backend")
        let container = DockerContainerResource(
            id: "api",
            name: "api",
            image: "frontend:latest",
            command: "",
            createdAt: "",
            runningFor: "",
            ports: "",
            state: "running",
            status: "Up",
            size: "",
            labels: [:]
        )
        let docker = DockerResourceSnapshot(
            context: "colima",
            collectedAt: Date(),
            containers: [container],
            images: [],
            volumes: [],
            networks: [],
            stats: [],
            diskUsage: [],
            issues: [],
            commandRuns: []
        )
        let index = BackendSearchIndexer().index(profiles: [profile], docker: docker)

        let results = index.search(BackendSearchQuery(text: "api"))

        #expect(results.first?.title == "api")
    }

    @Test func searchIndexRedactsSecretsFromTokensAndIssueText() {
        let profile = Self.profile(named: "frontend", rawSummary: "TOKEN=abc123")
        let issue = BackendIssue(
            severity: .error,
            source: .docker,
            title: "Docker failed",
            message: "Authorization: Bearer deadbeef",
            command: "docker login --password hunter2",
            recoverySuggestion: "Set API_TOKEN=abc123"
        )
        let docker = DockerResourceSnapshot(
            context: "colima",
            collectedAt: Date(),
            containers: [],
            images: [],
            volumes: [],
            networks: [],
            stats: [],
            diskUsage: [],
            issues: [issue],
            commandRuns: [
                ManagedCommandRun(
                    request: ManagedCommandRequest(toolName: "docker", arguments: ["login", "--password", "hunter2"], purpose: "Login"),
                    executablePath: "/opt/homebrew/bin/docker",
                    launchedAt: Date(),
                    duration: 0,
                    terminationStatus: 1,
                    standardOutput: "TOKEN=abc123",
                    standardError: #"{"password":"hunter2"}"#
                )
            ]
        )

        let index = BackendSearchIndexer().index(profiles: [profile], docker: docker)
        let haystack = index.results.flatMap { [$0.title, $0.subtitle] + $0.tokens }.joined(separator: " ")

        #expect(!haystack.contains("abc123"))
        #expect(!haystack.contains("hunter2"))
        #expect(!haystack.contains("deadbeef"))
    }

    @Test func metricsParseCommaFormattedNumericPrefixes() {
        let profile = Self.profile(named: "api")
        let kubernetes = KubernetesResourceSnapshot(
            context: "colima",
            collectedAt: Date(),
            nodes: [],
            namespaces: [],
            pods: [],
            services: [],
            deployments: [],
            metrics: [
                KubernetesMetricResource(id: "pod/api", ownerKind: .pod, namespace: "default", name: "api", cpu: "1,250m", memory: "64Mi")
            ],
            issues: [],
            commandRuns: []
        )

        let samples = BackendMetricsCollector().metrics(profile: profile, docker: nil, kubernetes: kubernetes)

        #expect(samples.first { $0.id == "pod/api:cpu" }?.value == 1250)
    }

    private static func profile(named name: String, state: ProfileState = .running, rawSummary: String = "") -> ColimaProfile {
        ColimaProfile(
            name: name,
            state: state,
            runtime: .docker,
            architecture: .aarch64,
            resources: .standard,
            diskUsage: "",
            ipAddress: "",
            dockerContext: name == "default" ? "colima" : "colima-\(name)",
            kubernetes: .disabled,
            vmType: .vz,
            mountType: .virtiofs,
            socket: "",
            rawSummary: rawSummary
        )
    }
}
