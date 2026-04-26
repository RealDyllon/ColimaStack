import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct AppStateBackendAggregationTests {
    @Test func refreshAllUsesSelectedProfileForDetailAndBackendAggregation() async {
        let colima = RecordingFakeColima(
            profiles: [
                Self.profile(named: "default", state: .running),
                Self.profile(named: "dev", state: .running)
            ]
        )
        colima.statusByProfile["dev"] = Self.detail(profile: "dev", state: .running)
        colima.logsByProfile["dev"] = "dev logs"

        let backend = RecordingBackendSnapshotProvider()
        backend.snapshotsByProfile["dev"] = Self.backendSnapshot(
            profile: Self.profile(named: "dev", state: .running),
            status: Self.detail(profile: "dev", state: .running),
            issues: [
                BackendIssue(
                    severity: .warning,
                    source: .docker,
                    title: "Orphaned container",
                    message: "container has no owner",
                    recoverySuggestion: "remove it"
                )
            ]
        )

        let state = AppState(colima: colima, backend: backend)
        state.selectedProfileID = "dev"

        await state.refreshAll()

        #expect(colima.statusRequests == ["dev"])
        #expect(colima.logRequests == ["dev"])
        #expect(backend.snapshotRequests.map(\.profile.name) == ["dev"])
        #expect(state.selectedProfileDetail?.profileName == "dev")
        #expect(state.backendSnapshot?.profile.name == "dev")
        #expect(state.backendIssues.map(\.title) == ["Orphaned container"])
    }

    @Test func refreshProfileSkipsBackendAggregationAndClearsStaleSnapshotWhenProfileStops() async {
        let colima = RecordingFakeColima()
        colima.statusByProfile["default"] = Self.detail(profile: "default", state: .stopped)

        let backend = RecordingBackendSnapshotProvider()
        let state = AppState(colima: colima, profiles: [Self.profile(named: "default", state: .running)], backend: backend)
        state.selectedProfileID = "default"
        state.backendSnapshot = Self.backendSnapshot(
            profile: Self.profile(named: "default", state: .running),
            status: Self.detail(profile: "default", state: .running),
            issues: [
                BackendIssue(severity: .error, source: .docker, title: "Old issue", message: "stale")
            ]
        )
        state.backendIssues = state.backendSnapshot?.issues ?? []

        await state.refreshProfile("default")

        #expect(backend.snapshotRequests.isEmpty)
        #expect(state.selectedProfileDetail?.state == .stopped)
        #expect(state.backendSnapshot == nil)
        #expect(state.backendIssues.isEmpty)
        let oldIssueIsIndexed = state.backendSearchIndex.results.contains {
            $0.kind == .issue && $0.title == "Old issue"
        }
        #expect(!oldIssueIsIndexed)
    }

    @Test func refreshProfileSurfacesLogErrorsWithoutCallingBackendProvider() async {
        let colima = RecordingFakeColima()
        colima.statusByProfile["default"] = Self.detail(profile: "default", state: .running)
        colima.logsError = AppStateAggregationTestError(message: "log read failed")

        let backend = RecordingBackendSnapshotProvider()
        let state = AppState(colima: colima, profiles: [Self.profile(named: "default", state: .running)], backend: backend)

        await state.refreshProfile("default")

        #expect(state.presentedError?.message == "log read failed")
        #expect(state.selectedProfileDetail?.state == .running)
        #expect(backend.snapshotRequests.isEmpty)
    }

    @Test func refreshProfileAppendsRealtimeMonitorUsageSample() async {
        let colima = RecordingFakeColima()
        colima.statusByProfile["default"] = Self.detail(profile: "default", state: .running)

        let backend = RecordingBackendSnapshotProvider()
        backend.snapshotsByProfile["default"] = Self.backendSnapshot(
            profile: Self.profile(named: "default", state: .running),
            status: Self.detail(profile: "default", state: .running),
            dockerStats: [
                DockerStatsResource(
                    id: "abc123",
                    name: "api",
                    cpuPercent: "12.5%",
                    memoryUsage: "64MiB / 1GiB",
                    memoryPercent: "6.25%",
                    networkIO: "1kB / 2kB",
                    blockIO: "3kB / 4kB",
                    pids: "9"
                )
            ],
            diskUsage: [
                DockerDiskUsageResource(type: "Images", totalCount: "3", activeCount: "1", size: "1.2GB", reclaimable: "")
            ],
            issues: []
        )
        let state = AppState(colima: colima, profiles: [Self.profile(named: "default", state: .running)], backend: backend)

        await state.refreshProfile("default")

        guard let sample = state.monitorHistory.first else {
            Issue.record("Expected a monitor sample")
            return
        }
        #expect(sample.profileName == "default")
        #expect(sample.cpuPercent == 12.5)
        #expect(sample.memoryUsedBytes == 67_108_864)
        #expect(sample.diskUsedBytes == 1_200_000_000)
        #expect(sample.networkReceiveBytes == 1_000)
        #expect(sample.networkTransmitBytes == 2_000)
        #expect(sample.blockReadBytes == 3_000)
        #expect(sample.blockWriteBytes == 4_000)
    }

    @Test func runtimeUsageSamplesHaveStableUniqueIdentities() {
        let snapshot = Self.backendSnapshot(
            profile: Self.profile(named: "default", state: .running),
            status: Self.detail(profile: "default", state: .running),
            issues: []
        )

        let first = snapshot.runtimeUsageSample()
        let second = snapshot.runtimeUsageSample()

        #expect(first.id != second.id)
    }

    @Test func refreshProfileTrimsMonitorHistoryPerProfile() async {
        let colima = RecordingFakeColima()
        colima.statusByProfile["default"] = Self.detail(profile: "default", state: .running)

        let backend = RecordingBackendSnapshotProvider()
        backend.snapshotsByProfile["default"] = Self.backendSnapshot(
            profile: Self.profile(named: "default", state: .running),
            status: Self.detail(profile: "default", state: .running),
            issues: []
        )
        let state = AppState(colima: colima, profiles: [Self.profile(named: "default", state: .running)], backend: backend)
        state.monitorHistory = [
            Self.backendSnapshot(profile: Self.profile(named: "dev", state: .running), status: Self.detail(profile: "dev", state: .running), issues: []).runtimeUsageSample(),
            Self.backendSnapshot(profile: Self.profile(named: "dev", state: .running), status: Self.detail(profile: "dev", state: .running), issues: []).runtimeUsageSample()
        ]

        for _ in 0..<95 {
            await state.refreshProfile("default")
        }

        #expect(state.monitorHistory.filter { $0.profileID == "default" }.count == 90)
        #expect(state.monitorHistory.filter { $0.profileID == "dev" }.count == 2)
    }

    @Test func successfulCommandRecordsSucceededEntryAndIndexesCommandOutput() async {
        let colima = RecordingFakeColima()
        colima.commandResult = ProcessResult(
            request: ProcessRequest(arguments: ["colima", "start"]),
            exitCode: 0,
            stdout: "vm started",
            stderr: ""
        )

        let state = AppState(colima: colima, profiles: [Self.profile(named: "default", state: .running)])
        state.selectedProfileID = "default"

        await state.startSelected()

        guard let entry = state.commandLog.first else {
            Issue.record("Expected a command log entry")
            return
        }
        #expect(entry.command == "Start default")
        #expect(entry.status == .succeeded)
        #expect(entry.output == "vm started")
        let results = state.backendSearchIndex.search(.init(text: "vm started", sources: [.command]))
        #expect(results.count == 1)
        #expect(results.first?.kind == .command)
        #expect(results.first?.title == "Start default")
    }

    @Test func commandLogRedactsBeforeTruncatingLongOutput() async {
        let colima = RecordingFakeColima()
        colima.commandResult = ProcessResult(
            request: ProcessRequest(arguments: ["colima", "start"]),
            exitCode: 0,
            stdout: String(repeating: "x", count: 200_010) + " TOKEN=abc123",
            stderr: ""
        )

        let state = AppState(colima: colima, profiles: [Self.profile(named: "default", state: .running)])
        state.selectedProfileID = "default"

        await state.startSelected()

        let output = state.commandLog.first?.output ?? ""
        #expect(output.hasPrefix("[Output truncated to the last 200000 characters]"))
        #expect(output.contains("TOKEN=<redacted>"))
        #expect(!output.contains("abc123"))
    }

    @Test func failedCommandRecordsFailureAndIndexesErrorOutput() async {
        let colima = RecordingFakeColima()
        colima.commandError = AppStateAggregationTestError(message: "stop failed")

        let state = AppState(colima: colima, profiles: [Self.profile(named: "default", state: .running)])
        state.selectedProfileID = "default"

        await state.stopSelected()

        guard let entry = state.commandLog.first else {
            Issue.record("Expected a command log entry")
            return
        }
        guard case .failed("stop failed") = entry.status else {
            Issue.record("Expected a failed command entry")
            return
        }
        #expect(state.presentedError?.message == "stop failed")
        let results = state.backendSearchIndex.search(.init(text: "stop failed", sources: [.command]))
        #expect(results.count == 1)
        #expect(results.first?.kind == .command)
        #expect(results.first?.subtitle == "Exited 1")
    }

    @Test func searchCanFilterStoppedProfilesWhenRequested() {
        let index = BackendSearchIndexer().index(
            profiles: [
                Self.profile(named: "default", state: .running),
                Self.profile(named: "archived", state: .stopped)
            ],
            docker: nil,
            kubernetes: nil,
            commands: []
        )

        let results = index.search(.init(text: "", sources: [.colima], includeStopped: false))

        #expect(results.map(\.title) == ["default"])
    }

    fileprivate static func profile(named name: String, state: ProfileState) -> ColimaProfile {
        ColimaProfile(
            name: name,
            state: state,
            runtime: .docker,
            architecture: .aarch64,
            resources: .standard,
            diskUsage: "",
            ipAddress: name == "default" ? "192.168.5.15" : "192.168.5.25",
            dockerContext: name == "default" ? "colima" : "colima-\(name)",
            kubernetes: .disabled,
            vmType: .qemu,
            mountType: .sshfs,
            socket: "unix:///tmp/\(name).sock",
            rawSummary: state.label
        )
    }

    fileprivate static func detail(profile: String, state: ProfileState) -> ColimaStatusDetail {
        ColimaStatusDetail(
            profileName: profile,
            state: state,
            runtime: .docker,
            architecture: .aarch64,
            vmType: .qemu,
            mountType: .sshfs,
            resources: .standard,
            kubernetes: .disabled,
            networkAddress: profile == "default" ? "192.168.5.15" : "192.168.5.25",
            socket: "unix:///tmp/\(profile).sock",
            dockerContext: profile == "default" ? "colima" : "colima-\(profile)",
            errors: [],
            rawOutput: ""
        )
    }

    fileprivate static func backendSnapshot(
        profile: ColimaProfile,
        status: ColimaStatusDetail,
        dockerStats: [DockerStatsResource] = [],
        diskUsage: [DockerDiskUsageResource] = [],
        issues: [BackendIssue]
    ) -> ColimaBackendSnapshot {
        ColimaBackendSnapshot(
            profile: profile,
            status: status,
            docker: DockerResourceSnapshot(
                context: status.dockerContext,
                collectedAt: Date(),
                containers: [],
                images: [],
                volumes: [],
                networks: [],
                stats: dockerStats,
                diskUsage: diskUsage,
                issues: issues,
                commandRuns: []
            ),
            kubernetes: nil,
            metrics: [],
            issues: issues,
            collectedAt: Date()
        )
    }
}

private struct AppStateAggregationTestError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

@MainActor
private final class RecordingBackendSnapshotProvider: BackendSnapshotProviding {
    private(set) var snapshotRequests: [(profile: ColimaProfile, status: ColimaStatusDetail)] = []
    var snapshotsByProfile: [String: ColimaBackendSnapshot] = [:]

    func snapshot(profile: ColimaProfile, status: ColimaStatusDetail) async -> ColimaBackendSnapshot {
        snapshotRequests.append((profile: profile, status: status))
        return snapshotsByProfile[profile.name]
            ?? AppStateBackendAggregationTests.backendSnapshot(profile: profile, status: status, issues: [])
    }
}

@MainActor
private final class RecordingFakeColima: ColimaControlling {
    var profiles: [ColimaProfile]
    var statusByProfile: [String: ColimaStatusDetail] = [:]
    var logsByProfile: [String: String] = [:]
    var logsError: Error?
    var commandError: Error?
    var commandResult = ProcessResult(
        request: ProcessRequest(arguments: ["colima", "command"]),
        exitCode: 0,
        stdout: "ok",
        stderr: ""
    )

    private(set) var statusRequests: [String] = []
    private(set) var logRequests: [String] = []

    init(profiles: [ColimaProfile]? = nil) {
        self.profiles = profiles ?? [AppStateBackendAggregationTests.profile(named: "default", state: .running)]
    }

    func diagnostics() async -> DiagnosticReport { .empty }

    func listProfiles() async throws -> [ColimaProfile] { profiles }

    func status(profile: String) async throws -> ColimaStatusDetail {
        statusRequests.append(profile)
        return statusByProfile[profile] ?? AppStateBackendAggregationTests.detail(profile: profile, state: .running)
    }

    func logs(profile: String) async throws -> String {
        logRequests.append(profile)
        if let logsError { throw logsError }
        return logsByProfile[profile] ?? "logs for \(profile)"
    }

    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult { try result() }
    func stop(profile: String) async throws -> ProcessResult { try result() }
    func restart(profile: String) async throws -> ProcessResult { try result() }
    func delete(profile: String) async throws -> ProcessResult { try result() }
    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult { try result() }
    func update(profile: String) async throws -> ProcessResult { try result() }
    func template() async throws -> String { "" }
    func configuration(profile: String) async throws -> ProfileConfiguration? { nil }

    private func result() throws -> ProcessResult {
        if let commandError { throw commandError }
        return commandResult
    }
}
