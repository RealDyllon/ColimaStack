import Combine
import Foundation
import SwiftUI

enum AutoRefreshFrequency: String, CaseIterable, Identifiable {
    case faster
    case fast
    case normal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .faster: "Faster"
        case .fast: "Fast"
        case .normal: "Normal"
        }
    }

    var duration: Duration {
        switch self {
        case .faster: .seconds(2)
        case .fast: .seconds(5)
        case .normal: .seconds(10)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var profiles: [ColimaProfile]
    @Published var selectedProfileID: ColimaProfile.ID?
    @Published var selectedSection: WorkspaceRoute = .overview
    @Published var selectedProfileDetail: ColimaStatusDetail?
    @Published var backendSnapshot: ColimaBackendSnapshot?
    @Published var backendIssues: [BackendIssue] = []
    @Published var monitorHistory: [RuntimeUsageSample] = []
    @Published var backendSearchIndex = BackendSearchIndex(collectedAt: Date(), results: [])
    @Published var searchText = ""
    @Published var logs: String = ""
    @Published var diagnostics: DiagnosticReport = .empty
    @Published var commandLog: [CommandLogEntry] = []
    @Published var isRefreshing = false
    @Published var activeOperation: String?
    @Published var presentedError: AppError?
    @Published var isShowingProfileEditor = false
    @Published var editingConfiguration: ProfileConfiguration = .default
    @Published var autoRefresh = true
    @Published var autoRefreshFrequency: AutoRefreshFrequency = .normal

    private let colima: ColimaControlling
    private let backend: BackendSnapshotProviding?
    private let searchIndexer: BackendSearchIndexing
    private let maxMonitorHistorySamples = 90
    private let maxCommandLogEntries = 200
    private var profileEditorTask: Task<Void, Never>?

    init(
        colima: ColimaControlling,
        profiles: [ColimaProfile] = [],
        backend: BackendSnapshotProviding? = nil,
        searchIndexer: BackendSearchIndexing? = nil
    ) {
        self.colima = colima
        self.backend = backend
        self.searchIndexer = searchIndexer ?? BackendSearchIndexer()
        self.profiles = profiles
        self.selectedProfileID = profiles.first?.id
        rebuildSearchIndex()
    }

    static func live() -> AppState {
        AppState(colima: LiveColimaCLI(), backend: LiveBackendSnapshotService())
    }

    static func preview() -> AppState {
        PreviewSupport.appState
    }

    var selectedProfile: ColimaProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    var hasCollectedDiagnostics: Bool {
        diagnostics.tools.contains { $0.id == "colima" }
    }

    var hasColima: Bool {
        diagnostics.tools.first(where: { $0.id == "colima" }).map {
            if case .available = $0.availability { return true }
            return false
        } ?? false
    }

    func launch() async {
        await refreshAll()
    }

    func runAutoRefreshLoop() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: autoRefreshFrequency.duration)
            } catch {
                return
            }

            guard autoRefresh, activeOperation == nil, !isShowingProfileEditor else { continue }
            await refreshAll()
        }
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        diagnostics = await colima.diagnostics()
        do {
            let previousProfiles = profiles
            profiles = mergeFreshProfiles(try await colima.listProfiles(), preservingDetailsFrom: previousProfiles)
            if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
                selectedProfileID = profiles.first?.id
            }
            if let selectedProfileID {
                await refreshProfile(selectedProfileID)
            }
        } catch ColimaCLIError.missingColima {
            profiles = []
            selectedProfileDetail = nil
            backendSnapshot = nil
            backendIssues = [
                BackendIssue(
                    severity: .error,
                    source: .tooling,
                    title: "Colima is not installed",
                    message: "Install Colima with Homebrew or another supported package manager, then refresh setup checks.",
                    recoverySuggestion: "Run `brew install colima` in your terminal."
                )
            ]
            logs = ""
            rebuildSearchIndex()
        } catch {
            presentedError = AppError(message: error.localizedDescription)
        }
    }

    private func mergeFreshProfiles(_ freshProfiles: [ColimaProfile], preservingDetailsFrom previousProfiles: [ColimaProfile]) -> [ColimaProfile] {
        freshProfiles.map { freshProfile in
            guard let previousProfile = previousProfiles.first(where: { $0.id == freshProfile.id }) else {
                return freshProfile
            }

            var mergedProfile = freshProfile
            mergedProfile.runtime = freshProfile.runtime ?? previousProfile.runtime
            mergedProfile.architecture = freshProfile.architecture ?? previousProfile.architecture
            mergedProfile.resources = freshProfile.resources ?? previousProfile.resources
            mergedProfile.diskUsage = freshProfile.diskUsage.nonEmpty ?? previousProfile.diskUsage
            mergedProfile.ipAddress = freshProfile.ipAddress.nonEmpty ?? previousProfile.ipAddress
            mergedProfile.dockerContext = freshProfile.dockerContext.nonEmpty ?? previousProfile.dockerContext
            if !freshProfile.kubernetes.enabled, previousProfile.kubernetes.enabled {
                mergedProfile.kubernetes = previousProfile.kubernetes
            }
            mergedProfile.vmType = freshProfile.vmType ?? previousProfile.vmType
            mergedProfile.mountType = freshProfile.mountType ?? previousProfile.mountType
            mergedProfile.socket = freshProfile.socket.nonEmpty ?? previousProfile.socket
            if freshProfile.mounts.isEmpty {
                mergedProfile.mounts = previousProfile.mounts
            }
            return mergedProfile
        }
    }

    func refreshProfile(_ profile: String) async {
        do {
            selectedProfileDetail = try await colima.status(profile: profile)
            if let detail = selectedProfileDetail, let index = profiles.firstIndex(where: { $0.id == profile }) {
                profiles[index].state = detail.state
                profiles[index].runtime = detail.runtime ?? profiles[index].runtime
                profiles[index].architecture = detail.architecture ?? profiles[index].architecture
                profiles[index].resources = detail.resources ?? profiles[index].resources
                profiles[index].kubernetes = detail.kubernetes
                profiles[index].vmType = detail.vmType
                profiles[index].mountType = detail.mountType
                profiles[index].socket = detail.socket
                profiles[index].ipAddress = detail.networkAddress
                if let configuration = try? await colima.configuration(profile: profile) {
                    profiles[index].mounts = configuration.mounts.map {
                        ColimaMount(
                            location: $0.localPath,
                            mountPoint: $0.vmPath.isEmpty ? nil : $0.vmPath,
                            writable: $0.writable,
                            cliValue: $0.commandValue
                        )
                    }
                }
            }
            logs = try await colima.logs(profile: profile)
            if let backend, let selectedProfile, let selectedProfileDetail, selectedProfile.state == .running {
                let snapshot = await backend.snapshot(profile: selectedProfile, status: selectedProfileDetail)
                backendSnapshot = snapshot
                backendIssues = snapshot.issues
                appendMonitorSample(from: snapshot)
            } else {
                backendSnapshot = nil
                backendIssues = []
            }
            rebuildSearchIndex()
        } catch {
            presentedError = AppError(message: error.localizedDescription)
        }
    }

    func startSelected() async {
        guard let profile = selectedProfile else { return }
        let configuration = await configuration(for: profile)
        await runCommand("Start \(profile.name)") { try await colima.start(configuration) }
    }

    func stopSelected() async {
        guard let selectedProfileID else { return }
        await runCommand("Stop \(selectedProfileID)") { try await colima.stop(profile: selectedProfileID) }
    }

    func restartSelected() async {
        guard let selectedProfileID else { return }
        await runCommand("Restart \(selectedProfileID)") { try await colima.restart(profile: selectedProfileID) }
    }

    func deleteSelected() async {
        guard let selectedProfileID else { return }
        await runCommand("Delete \(selectedProfileID)") { try await colima.delete(profile: selectedProfileID) }
    }

    func updateSelected() async {
        guard let selectedProfileID else { return }
        await runCommand("Update \(selectedProfileID)") { try await colima.update(profile: selectedProfileID) }
    }

    func setKubernetes(enabled: Bool) async {
        guard let selectedProfileID else { return }
        await runCommand(enabled ? "Start Kubernetes" : "Stop Kubernetes") {
            try await colima.kubernetes(profile: selectedProfileID, enabled: enabled)
        }
    }

    func createProfile() {
        profileEditorTask?.cancel()
        editingConfiguration = .default
        isShowingProfileEditor = true
    }

    func editSelectedProfile() {
        guard let profile = selectedProfile else { return }
        profileEditorTask?.cancel()
        profileEditorTask = Task { [weak self] in
            guard let self else { return }
            editingConfiguration = await configuration(for: profile)
            guard !Task.isCancelled, selectedProfileID == profile.id else { return }
            isShowingProfileEditor = true
        }
    }

    func cancelProfileEditing() {
        profileEditorTask?.cancel()
        profileEditorTask = nil
        isShowingProfileEditor = false
    }

    private func configuration(for profile: ColimaProfile) async -> ProfileConfiguration {
        var configuration = ProfileConfiguration.default
        configuration.name = profile.name
        configuration.resources = profile.resources ?? .standard
        configuration.runtime = profile.runtime ?? .docker
        configuration.vmType = profile.vmType ?? .qemu
        configuration.architecture = profile.architecture ?? .host
        configuration.mountType = profile.mountType ?? .sshfs
        configuration.kubernetes = profile.kubernetes
        if let storedConfiguration = try? await colima.configuration(profile: profile.name) {
            configuration = storedConfiguration
        }
        return configuration
    }

    func saveEditingConfiguration() async {
        let configuration = editingConfiguration
        let succeeded = await runCommand("Apply \(configuration.name)") { try await colima.start(configuration) }
        if succeeded {
            profileEditorTask?.cancel()
            profileEditorTask = nil
            isShowingProfileEditor = false
        }
    }

    @discardableResult
    private func runCommand(_ label: String, operation: () async throws -> ProcessResult) async -> Bool {
        activeOperation = label
        var entry = CommandLogEntry(date: Date(), command: label, status: .running, output: "")
        commandLog.insert(entry, at: 0)
        trimCommandLog()
        defer { activeOperation = nil }
        do {
            let result = try await operation()
            entry.status = .succeeded
            entry.output = result.combinedOutput
            replaceCommandEntry(entry)
            await refreshAll()
            return true
        } catch {
            entry.status = .failed(error.localizedDescription)
            entry.output = error.localizedDescription
            replaceCommandEntry(entry)
            presentedError = AppError(message: error.localizedDescription)
            return false
        }
    }

    private func replaceCommandEntry(_ entry: CommandLogEntry) {
        if let index = commandLog.firstIndex(where: { $0.id == entry.id }) {
            commandLog[index] = entry
        }
        rebuildSearchIndex()
    }

    private func trimCommandLog() {
        guard commandLog.count > maxCommandLogEntries else { return }
        commandLog.removeSubrange(maxCommandLogEntries..<commandLog.endIndex)
    }

    private func appendMonitorSample(from snapshot: ColimaBackendSnapshot) {
        let sample = snapshot.runtimeUsageSample()
        monitorHistory.append(sample)
        let profileID = sample.profileID
        let profileSampleCount = monitorHistory.reduce(0) { count, existingSample in
            existingSample.profileID == profileID ? count + 1 : count
        }
        var remainingRemovals = profileSampleCount - maxMonitorHistorySamples
        guard remainingRemovals > 0 else { return }

        var index = monitorHistory.startIndex
        while index < monitorHistory.endIndex, remainingRemovals > 0 {
            if monitorHistory[index].profileID == profileID {
                monitorHistory.remove(at: index)
                remainingRemovals -= 1
            } else {
                index = monitorHistory.index(after: index)
            }
        }
    }

    private func rebuildSearchIndex() {
        let commandRuns = commandLog.map { entry in
            ManagedCommandRun(
                request: ManagedCommandRequest(toolName: "colimastack", arguments: [entry.command], purpose: entry.command),
                executablePath: "ColimaStack",
                launchedAt: entry.date,
                duration: 0,
                terminationStatus: entry.status.isFailed ? 1 : 0,
                standardOutput: entry.output,
                standardError: entry.status.failureMessage ?? ""
            )
        }
        backendSearchIndex = searchIndexer.index(
            profiles: profiles,
            docker: backendSnapshot?.docker,
            kubernetes: backendSnapshot?.kubernetes,
            commands: commandRuns
        )
    }
}

private extension CommandLogEntry.Status {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var failureMessage: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}

struct AppError: Identifiable, Equatable {
    let id = UUID()
    var message: String
}
