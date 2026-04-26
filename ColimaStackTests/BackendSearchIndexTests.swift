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
