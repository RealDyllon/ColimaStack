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
    @Published var selectedProfileID: ColimaProfile.ID? {
        didSet { persistSelectedProfileID() }
    }
    @Published var selectedSection: WorkspaceRoute = .overview {
        didSet { userDefaults?.set(selectedSection.rawValue, forKey: DefaultsKey.selectedSection) }
    }
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
    @Published var autoRefresh = true {
        didSet { userDefaults?.set(autoRefresh, forKey: DefaultsKey.autoRefresh) }
    }
    @Published var autoRefreshFrequency: AutoRefreshFrequency = .normal {
        didSet { userDefaults?.set(autoRefreshFrequency.rawValue, forKey: DefaultsKey.autoRefreshFrequency) }
    }
    @Published var hasCompletedDiagnostics = false

    private let colima: ColimaControlling
    private let backend: BackendSnapshotProviding?
    private let searchIndexer: BackendSearchIndexing
    private let userDefaults: UserDefaults?
    private let maxMonitorHistorySamples = 90
    private let maxCommandLogEntries = 200
    private let maxLogCharacters = 200_000
    private var profileEditorTask: Task<Void, Never>?
    private var refreshGeneration = 0

    init(
        colima: ColimaControlling,
        profiles: [ColimaProfile] = [],
        backend: BackendSnapshotProviding? = nil,
        searchIndexer: BackendSearchIndexing? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        self.colima = colima
        self.backend = backend
        self.searchIndexer = searchIndexer ?? BackendSearchIndexer()
        self.userDefaults = userDefaults
        self.profiles = profiles
        if let rawSection = userDefaults?.string(forKey: DefaultsKey.selectedSection),
           let section = WorkspaceRoute(rawValue: rawSection) {
            self.selectedSection = section
        }
        if userDefaults?.object(forKey: DefaultsKey.autoRefresh) != nil {
            self.autoRefresh = userDefaults?.bool(forKey: DefaultsKey.autoRefresh) ?? true
        }
        if let rawFrequency = userDefaults?.string(forKey: DefaultsKey.autoRefreshFrequency),
           let frequency = AutoRefreshFrequency(rawValue: rawFrequency) {
            self.autoRefreshFrequency = frequency
        }
        let persistedProfileID = userDefaults?.string(forKey: DefaultsKey.selectedProfileID)
        self.selectedProfileID = persistedProfileID.flatMap { id in profiles.contains(where: { $0.id == id }) ? id : nil } ?? profiles.first?.id
        rebuildSearchIndex()
    }

    static func live() -> AppState {
        AppState(colima: LiveColimaCLI(), backend: LiveBackendSnapshotService(), userDefaults: .standard)
    }

    static func preview() -> AppState {
        PreviewSupport.appState
    }

    var selectedProfile: ColimaProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    var hasCollectedDiagnostics: Bool {
        hasCompletedDiagnostics || diagnostics.tools.contains { $0.id == "colima" }
    }

    var hasColima: Bool {
        guard hasCollectedDiagnostics else { return false }
        return diagnostics.tools.first(where: { $0.id == "colima" }).map {
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
        refreshGeneration += 1
        let generation = refreshGeneration
        isRefreshing = true
        defer { isRefreshing = false }
        diagnostics = await colima.diagnostics()
        hasCompletedDiagnostics = true
        do {
            let previousProfiles = profiles
            let freshProfiles = try await colima.listProfiles()
            guard generation == refreshGeneration else { return }
            profiles = mergeFreshProfiles(freshProfiles, preservingDetailsFrom: previousProfiles)
            if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
                selectedProfileID = persistedSelectedProfileID(in: profiles) ?? profiles.first?.id
            }
            if let selectedProfileID {
                await refreshProfile(selectedProfileID, generation: generation)
            }
        } catch ColimaCLIError.missingColima {
            guard generation == refreshGeneration else { return }
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
            guard generation == refreshGeneration else { return }
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
        refreshGeneration += 1
        await refreshProfile(profile, generation: refreshGeneration)
    }

    private func refreshProfile(_ profile: String, generation: Int) async {
        do {
            let detail = try await colima.status(profile: profile)
            guard generation == refreshGeneration, selectedProfileID == profile else { return }
            selectedProfileDetail = detail
            if let index = profiles.firstIndex(where: { $0.id == profile }) {
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
            let profileLogs = try await colima.logs(profile: profile)
            guard generation == refreshGeneration, selectedProfileID == profile else { return }
            logs = cappedLog(profileLogs)
            if let backend, let selectedProfile, let selectedProfileDetail, selectedProfile.state == .running {
                let snapshot = await backend.snapshot(profile: selectedProfile, status: selectedProfileDetail)
                guard generation == refreshGeneration, selectedProfileID == profile else { return }
                backendSnapshot = snapshot
                backendIssues = snapshot.issues
                appendMonitorSample(from: snapshot)
            } else {
                backendSnapshot = nil
                backendIssues = []
            }
            rebuildSearchIndex()
        } catch {
            guard generation == refreshGeneration else { return }
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
        await delete(profileID: selectedProfileID)
    }

    func delete(profileID: ColimaProfile.ID) async {
        await runCommand("Delete \(profileID)") { try await colima.delete(profile: profileID) }
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
        if profiles.contains(where: { $0.name == configuration.name && $0.id != selectedProfileID }) {
            presentedError = AppError(message: "A profile named '\(configuration.name)' already exists.")
            return
        }
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
            entry.output = cappedLog(result.combinedOutput)
            replaceCommandEntry(entry)
            await refreshAll()
            return true
        } catch {
            entry.status = .failed(error.localizedDescription)
            entry.output = cappedLog(error.localizedDescription)
            replaceCommandEntry(entry)
            presentedError = AppError(message: error.localizedDescription)
            return false
        }
    }

    private func replaceCommandEntry(_ entry: CommandLogEntry) {
        if let index = commandLog.firstIndex(where: { $0.id == entry.id }) {
            commandLog[index] = entry
        }
        trimCommandLog()
        rebuildSearchIndex()
    }

    private func trimCommandLog() {
        guard commandLog.count > maxCommandLogEntries else { return }
        commandLog.removeSubrange(maxCommandLogEntries..<commandLog.endIndex)
    }

    private func cappedLog(_ value: String) -> String {
        let redacted = EnvironmentRedactor.redacted(value)
        guard redacted.count > maxLogCharacters else { return redacted }
        return "[Output truncated to the last \(maxLogCharacters) characters]\n" + String(redacted.suffix(maxLogCharacters))
    }

    private func persistedSelectedProfileID(in profiles: [ColimaProfile]) -> String? {
        guard let id = userDefaults?.string(forKey: DefaultsKey.selectedProfileID),
              profiles.contains(where: { $0.id == id }) else {
            return nil
        }
        return id
    }

    private func persistSelectedProfileID() {
        if let selectedProfileID {
            userDefaults?.set(selectedProfileID, forKey: DefaultsKey.selectedProfileID)
        } else {
            userDefaults?.removeObject(forKey: DefaultsKey.selectedProfileID)
        }
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

private enum DefaultsKey {
    static let selectedProfileID = "selectedProfileID"
    static let selectedSection = "selectedSection"
    static let autoRefresh = "autoRefresh"
    static let autoRefreshFrequency = "autoRefreshFrequency"
}

struct AppError: Identifiable, Equatable {
    let id = UUID()
    var message: String
}
