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

enum ProfileEditorMode: Equatable {
    case create
    case edit(profileID: ColimaProfile.ID)

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var profiles: [ColimaProfile]
    @Published var selectedProfileID: ColimaProfile.ID? {
        didSet {
            persistSelectedProfileID()
            guard oldValue != selectedProfileID else { return }
            clearSelectedProfilePayload()
        }
    }
    @Published var selectedSection: WorkspaceRoute = .overview {
        didSet { userDefaults?.set(selectedSection.rawValue, forKey: DefaultsKey.selectedSection) }
    }
    @Published var selectedProfileDetail: ColimaStatusDetail?
    @Published var backendSnapshot: ColimaBackendSnapshot?
    @Published var backendIssues: [BackendIssue] = []
    @Published var monitorHistory: [RuntimeUsageSample] = []
    @Published var backendSearchIndex = BackendSearchIndex(collectedAt: Date(), results: [])
    @Published var logs: String = ""
    @Published var diagnostics: DiagnosticReport = .empty
    @Published var commandLog: [CommandLogEntry] = []
    @Published var isRefreshing = false
    @Published var activeOperation: String?
    @Published var presentedError: AppError?
    @Published var isShowingProfileEditor = false
    @Published var profileEditorMode: ProfileEditorMode?
    @Published var editingConfiguration: ProfileConfiguration = .default
    /// The configuration as it was when the editor opened. Used to
    /// detect destructive field changes (runtime, vmType, diskGiB)
    /// that require a recreate confirmation.
    @Published var originalEditingConfiguration: ProfileConfiguration?
    @Published var autoRefresh = true {
        didSet { userDefaults?.set(autoRefresh, forKey: DefaultsKey.autoRefresh) }
    }
    @Published var autoRefreshFrequency: AutoRefreshFrequency = .normal {
        didSet { userDefaults?.set(autoRefreshFrequency.rawValue, forKey: DefaultsKey.autoRefreshFrequency) }
    }
    @Published var useStreamingCommandOutput = true {
        didSet { userDefaults?.set(useStreamingCommandOutput, forKey: DefaultsKey.useStreamingCommandOutput) }
    }
    @Published var useEventBus = true {
        didSet { userDefaults?.set(useEventBus, forKey: DefaultsKey.useEventBus) }
    }
    @Published var connectionStatus = RuntimeConnectionStatus()
    @Published var hasCompletedDiagnostics = false
    @Published var defaultTableDensity: TableDensity = .standard {
        didSet {
            guard oldValue != defaultTableDensity else { return }
            userDefaults?.set(defaultTableDensity.rawValue, forKey: DefaultsKey.tableDensity)
        }
    }
    @Published var tableColumnCustomization: TableColumnCustomization = .init()

    private let colima: ColimaControlling
    private let backend: BackendSnapshotProviding?
    private let searchIndexer: BackendSearchIndexing
    private let userDefaults: UserDefaults?
    private let maxMonitorHistorySamples = 90
    private let maxCommandLogEntries = 200
    private let maxLogCharacters = 200_000
    private var profileEditorTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var currentCommandTask: Task<Void, Never>?
    private var currentCommandCancellation: ProcessCancellation?
    private var toolCheckTask: Task<Void, Never>?
    /// Container lifecycle service. Owned by `AppState` so the
    /// notification subscribers outlive the per-screen views.
    public var containerService: ContainerService!

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
        self.containerService = nil
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
        if userDefaults?.object(forKey: DefaultsKey.useStreamingCommandOutput) != nil {
            self.useStreamingCommandOutput = userDefaults?.bool(forKey: DefaultsKey.useStreamingCommandOutput) ?? true
        }
        if userDefaults?.object(forKey: DefaultsKey.useEventBus) != nil {
            self.useEventBus = userDefaults?.bool(forKey: DefaultsKey.useEventBus) ?? true
        }
        if let rawDensity = userDefaults?.string(forKey: DefaultsKey.tableDensity),
           let density = TableDensity(rawValue: rawDensity) {
            self.defaultTableDensity = density
        }
        let persistedProfileID = userDefaults?.string(forKey: DefaultsKey.selectedProfileID)
        self.selectedProfileID = persistedProfileID.flatMap { id in profiles.contains(where: { $0.id == id }) ? id : nil } ?? profiles.first?.id
        rebuildSearchIndex()
        // Now that all stored properties are initialized, swap the
        // placeholder for a fully-wired ContainerService.
        self.containerService = ContainerService(appState: self)
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

    /// Exposed for `RuntimeEventEngine` to build the `ColimaFileWatcherSource`, which
    /// needs a `ColimaControlling` to run on-demand status probes.
    var colimaForEvents: ColimaControlling { colima }

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

    var canEditProfileName: Bool {
        if case .edit = profileEditorMode {
            return false
        }
        return true
    }

    var profileEditorActionTitle: String {
        if case .create = profileEditorMode {
            return "Create"
        }
        return "Apply"
    }

    func launch() async {
        await probeTools()
        await refreshAll()
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        isRefreshing = true
        defer { isRefreshing = false }
        let initialDiagnosticsProfile = selectedProfileID
        if !useEventBus {
            await refreshDiagnostics(profile: initialDiagnosticsProfile, generation: generation)
        }
        do {
            let previousProfiles = profiles
            let freshProfiles = try await colima.listProfiles()
            guard generation == refreshGeneration else { return }
            profiles = mergeFreshProfiles(freshProfiles, preservingDetailsFrom: previousProfiles)
            if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
                selectedProfileID = persistedSelectedProfileID(in: profiles) ?? profiles.first?.id
            }
            if let selectedProfileID {
                if selectedProfileID != initialDiagnosticsProfile, !useEventBus {
                    await refreshDiagnostics(profile: selectedProfileID, generation: generation)
                    guard generation == refreshGeneration else { return }
                }
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
        let generation = refreshGeneration
        await refreshDiagnostics(profile: profile, generation: generation)
        await refreshProfile(profile, generation: generation)
    }

    private func refreshDiagnostics(profile: String?, generation: Int) async {
        let report = await colima.diagnostics(profile: profile)
        guard generation == refreshGeneration else { return }
        diagnostics = report
        hasCompletedDiagnostics = true
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
            if useEventBus {
                // Docker/k8s state is driven by event sources; skip the snapshot poll.
                // Keep the existing backendSnapshot (if any) and let the reducer apply deltas.
            } else if let backend, let selectedProfile, let selectedProfileDetail, selectedProfile.state == .running {
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
        if useStreamingCommandOutput {
            await runStreamingCommand("Start \(profile.name)") { cancellation in
                self.colima.streamStart(configuration, cancellation: cancellation)
            }
        } else {
            await runCommand("Start \(profile.name)") { try await colima.start(configuration) }
        }
    }

    func stopSelected() async {
        guard let selectedProfileID else { return }
        if useStreamingCommandOutput {
            await runStreamingCommand("Stop \(selectedProfileID)") { cancellation in
                self.colima.streamStop(profile: selectedProfileID, cancellation: cancellation)
            }
        } else {
            await runCommand("Stop \(selectedProfileID)") { try await colima.stop(profile: selectedProfileID) }
        }
    }

    func restartSelected() async {
        guard let selectedProfileID else { return }
        if useStreamingCommandOutput {
            await runStreamingCommand("Restart \(selectedProfileID)") { cancellation in
                self.colima.streamRestart(profile: selectedProfileID, cancellation: cancellation)
            }
        } else {
            await runCommand("Restart \(selectedProfileID)") { try await colima.restart(profile: selectedProfileID) }
        }
    }

    func deleteSelected() async {
        guard let selectedProfileID else { return }
        await delete(profileID: selectedProfileID)
    }

    func delete(profileID: ColimaProfile.ID) async {
        if useStreamingCommandOutput {
            await runStreamingCommand("Delete \(profileID)") { cancellation in
                self.colima.streamDelete(profile: profileID, cancellation: cancellation)
            }
        } else {
            await runCommand("Delete \(profileID)") { try await colima.delete(profile: profileID) }
        }
    }

    func updateSelected() async {
        guard let selectedProfileID else { return }
        if useStreamingCommandOutput {
            await runStreamingCommand("Update \(selectedProfileID)") { cancellation in
                self.colima.streamUpdate(profile: selectedProfileID, cancellation: cancellation)
            }
        } else {
            await runCommand("Update \(selectedProfileID)") { try await colima.update(profile: selectedProfileID) }
        }
    }

    func setKubernetes(enabled: Bool) async {
        guard let selectedProfileID else { return }
        let label = enabled ? "Start Kubernetes" : "Stop Kubernetes"
        if useStreamingCommandOutput {
            await runStreamingCommand(label) { cancellation in
                self.colima.streamKubernetes(profile: selectedProfileID, enabled: enabled, cancellation: cancellation)
            }
        } else {
            await runCommand(label) {
                try await colima.kubernetes(profile: selectedProfileID, enabled: enabled)
            }
        }
    }

    /// Cancel the currently running lifecycle command (if any). Terminates the child
    /// process via `ProcessCancellation` and cancels the consuming task.
    func cancelCurrentCommand() {
        currentCommandCancellation?.cancel()
        currentCommandTask?.cancel()
    }

    func createProfile() {
        profileEditorTask?.cancel()
        profileEditorTask = nil
        profileEditorMode = .create
        editingConfiguration = .default
        isShowingProfileEditor = true
    }

    func editSelectedProfile() {
        guard let profile = selectedProfile else { return }
        profileEditorTask?.cancel()
        profileEditorTask = Task { [weak self] in
            guard let self else { return }
            let configuration = await configuration(for: profile)
            guard !Task.isCancelled, selectedProfileID == profile.id else { return }
            originalEditingConfiguration = configuration
            editingConfiguration = configuration
            profileEditorMode = .edit(profileID: profile.id)
            isShowingProfileEditor = true
        }
    }

    /// True if the current edit changed a field that requires the
    /// profile to be recreated (runtime, vmType, diskGiB).
    var hasDestructiveFieldChange: Bool {
        guard let original = originalEditingConfiguration else { return false }
        return original.runtime != editingConfiguration.runtime
            || original.vmType != editingConfiguration.vmType
            || original.resources.diskGiB != editingConfiguration.resources.diskGiB
    }

    func cancelProfileEditing() {
        profileEditorTask?.cancel()
        profileEditorTask = nil
        profileEditorMode = nil
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
        let mode = profileEditorMode ?? .create
        let commandLabel: String
        switch mode {
        case .create:
            if profiles.contains(where: { $0.name == configuration.name }) {
                presentedError = AppError(message: "A profile named '\(configuration.name)' already exists.")
                return
            }
            commandLabel = "Create \(configuration.name)"
        case let .edit(profileID):
            guard configuration.name == profileID else {
                presentedError = AppError(message: "Profile renaming is not supported. Keep the name '\(profileID)' or create a new profile.")
                return
            }
            commandLabel = "Apply \(profileID)"
        }
        let succeeded: Bool
        if useStreamingCommandOutput {
            succeeded = await runStreamingCommand(commandLabel) { cancellation in
                self.colima.streamStart(configuration, cancellation: cancellation)
            }
        } else {
            succeeded = await runCommand(commandLabel) { try await colima.start(configuration) }
        }
        if succeeded {
            profileEditorTask?.cancel()
            profileEditorTask = nil
            profileEditorMode = nil
            isShowingProfileEditor = false
        }
    }

    @discardableResult
    private func runStreamingCommand(
        _ label: String,
        stream: (ProcessCancellation) -> AsyncThrowingStream<StreamingProcessEvent, Error>
    ) async -> Bool {
        activeOperation = label
        let cancellation = ProcessCancellation()
        currentCommandCancellation = cancellation
        var entry = CommandLogEntry(date: Date(), command: label, status: .running, output: "")
        commandLog.insert(entry, at: 0)
        trimCommandLog()
        defer {
            activeOperation = nil
            currentCommandCancellation = nil
        }
        do {
            for try await event in stream(cancellation) {
                switch event {
                case .chunk(let chunk):
                    let redacted = chunk.redactedString()
                    if !redacted.isEmpty {
                        entry.output = cappedLog(entry.output + redacted)
                        replaceCommandEntry(entry)
                    }
                case .result(let result):
                    entry.output = cappedLog(result.combinedOutput)
                    if result.terminationStatus == 0 {
                        entry.status = .succeeded
                    } else {
                        entry.status = .failed("Exited with status \(result.terminationStatus)")
                    }
                    replaceCommandEntry(entry)
                }
            }
            // If the stream ended without a terminal .result event, treat as succeeded.
            if case .running = entry.status {
                entry.status = .succeeded
                replaceCommandEntry(entry)
            }
            if case .failed = entry.status {
                presentedError = AppError(message: entry.output.isEmpty ? "Command failed" : entry.output)
                return false
            }
            await refreshAll()
            return true
        } catch is CancellationError {
            entry.status = .failed("Cancelled")
            replaceCommandEntry(entry)
            return false
        } catch {
            entry.status = .failed(error.localizedDescription)
            entry.output = cappedLog(error.localizedDescription)
            replaceCommandEntry(entry)
            presentedError = AppError(message: error.localizedDescription)
            return false
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

    private func clearSelectedProfilePayload() {
        selectedProfileDetail = nil
        backendSnapshot = nil
        backendIssues = []
        logs = ""
        rebuildSearchIndex()
    }

    // MARK: - Event reducer

    /// Apply a single `RuntimeEvent` as a delta to the minimal affected published slice.
    /// Does NOT spawn subprocesses. Called by `RuntimeEventEngine` on the main actor.
    func reduce(_ event: RuntimeEvent) {
        switch event {
        case let .snapshotReplaced(_, dockerSlice, k8sSlice):
            ensureBackendSnapshot()
            if let dockerSlice {
                backendSnapshot?.docker = DockerResourceSnapshot(
                    context: dockerSlice.context,
                    collectedAt: Date(),
                    containers: dockerSlice.containers,
                    images: dockerSlice.images,
                    volumes: dockerSlice.volumes,
                    networks: dockerSlice.networks,
                    stats: dockerSlice.stats,
                    diskUsage: dockerSlice.diskUsage,
                    issues: backendSnapshot?.docker?.issues ?? [],
                    commandRuns: backendSnapshot?.docker?.commandRuns ?? []
                )
            }
            if let k8sSlice {
                backendSnapshot?.kubernetes = KubernetesResourceSnapshot(
                    context: k8sSlice.context,
                    collectedAt: Date(),
                    nodes: k8sSlice.nodes,
                    namespaces: k8sSlice.namespaces,
                    pods: k8sSlice.pods,
                    services: k8sSlice.services,
                    deployments: k8sSlice.deployments,
                    metrics: k8sSlice.metrics,
                    issues: backendSnapshot?.kubernetes?.issues ?? [],
                    commandRuns: backendSnapshot?.kubernetes?.commandRuns ?? []
                )
            }
            rebuildSearchIndex()

        case let .dockerItem(kind, change, id, record):
            applyDockerDelta(kind: kind, change: change, id: id, record: record)
            rebuildSearchIndex()

        case let .kubernetesItem(kind, change, id, record):
            applyKubernetesDelta(kind: kind, change: change, id: id, record: record)
            rebuildSearchIndex()

        case let .colimaStatusUpdated(detail):
            selectedProfileDetail = detail
            if let index = profiles.firstIndex(where: { $0.id == detail.profileName }) {
                profiles[index].state = detail.state
                profiles[index].runtime = detail.runtime ?? profiles[index].runtime
                profiles[index].architecture = detail.architecture ?? profiles[index].architecture
                profiles[index].resources = detail.resources ?? profiles[index].resources
                profiles[index].kubernetes = detail.kubernetes
                profiles[index].vmType = detail.vmType
                profiles[index].mountType = detail.mountType
                profiles[index].socket = detail.socket
                profiles[index].ipAddress = detail.networkAddress
            }

        case let .logAppended(appended):
            logs = cappedLog(logs + appended)

        case let .statsSample(sample):
            appendRuntimeUsageSample(sample)

        case let .connectionStateChanged(source, state):
            switch source {
            case .docker: connectionStatus.docker = state
            case .kubernetes: connectionStatus.kubernetes = state
            case .colima: connectionStatus.colima = state
            }

        case let .issue(issue):
            backendIssues.append(issue)
        }
    }

    private func ensureBackendSnapshot() {
        if backendSnapshot == nil, let profile = selectedProfile {
            let detail = selectedProfileDetail ?? profile.statusDetail
            backendSnapshot = ColimaBackendSnapshot(
                profile: profile,
                status: detail,
                docker: nil,
                kubernetes: nil,
                metrics: [],
                issues: [],
                collectedAt: Date()
            )
        }
    }

    private func applyDockerDelta(kind: DockerResourceKind, change: ChangeKind, id: String, record: AnyRuntimeRecord?) {
        ensureBackendSnapshot()
        guard var docker = backendSnapshot?.docker else { return }
        switch kind {
        case .container:
            switch change {
            case .added, .modified:
                if let index = docker.containers.firstIndex(where: { $0.id == id }) {
                    if case let .container(c) = record { docker.containers[index] = c }
                } else if case let .container(c) = record {
                    docker.containers.append(c)
                }
            case .removed:
                docker.containers.removeAll { $0.id == id }
            }
        case .image:
            switch change {
            case .added, .modified:
                if let index = docker.images.firstIndex(where: { $0.id == id }) {
                    if case let .image(i) = record { docker.images[index] = i }
                } else if case let .image(i) = record {
                    docker.images.append(i)
                }
            case .removed:
                docker.images.removeAll { $0.id == id }
            }
        case .volume:
            switch change {
            case .added, .modified:
                if let index = docker.volumes.firstIndex(where: { $0.id == id }) {
                    if case let .volume(v) = record { docker.volumes[index] = v }
                } else if case let .volume(v) = record {
                    docker.volumes.append(v)
                }
            case .removed:
                docker.volumes.removeAll { $0.id == id }
            }
        case .network:
            switch change {
            case .added, .modified:
                if let index = docker.networks.firstIndex(where: { $0.id == id }) {
                    if case let .network(n) = record { docker.networks[index] = n }
                } else if case let .network(n) = record {
                    docker.networks.append(n)
                }
            case .removed:
                docker.networks.removeAll { $0.id == id }
            }
        }
        docker.collectedAt = Date()
        backendSnapshot?.docker = docker
    }

    private func applyKubernetesDelta(kind: KubernetesResourceKind, change: ChangeKind, id: String, record: AnyRuntimeRecord?) {
        ensureBackendSnapshot()
        guard var k8s = backendSnapshot?.kubernetes else { return }
        switch kind {
        case .node:
            switch change {
            case .added, .modified:
                if let index = k8s.nodes.firstIndex(where: { $0.id == id }) {
                    if case let .node(n) = record { k8s.nodes[index] = n }
                } else if case let .node(n) = record {
                    k8s.nodes.append(n)
                }
            case .removed:
                k8s.nodes.removeAll { $0.id == id }
            }
        case .namespace:
            switch change {
            case .added, .modified:
                if let index = k8s.namespaces.firstIndex(where: { $0.id == id }) {
                    if case let .namespace(n) = record { k8s.namespaces[index] = n }
                } else if case let .namespace(n) = record {
                    k8s.namespaces.append(n)
                }
            case .removed:
                k8s.namespaces.removeAll { $0.id == id }
            }
        case .pod:
            switch change {
            case .added, .modified:
                if let index = k8s.pods.firstIndex(where: { $0.id == id }) {
                    if case let .pod(p) = record { k8s.pods[index] = p }
                } else if case let .pod(p) = record {
                    k8s.pods.append(p)
                }
            case .removed:
                k8s.pods.removeAll { $0.id == id }
            }
        case .service:
            switch change {
            case .added, .modified:
                if let index = k8s.services.firstIndex(where: { $0.id == id }) {
                    if case let .service(s) = record { k8s.services[index] = s }
                } else if case let .service(s) = record {
                    k8s.services.append(s)
                }
            case .removed:
                k8s.services.removeAll { $0.id == id }
            }
        case .deployment:
            switch change {
            case .added, .modified:
                if let index = k8s.deployments.firstIndex(where: { $0.id == id }) {
                    if case let .deployment(d) = record { k8s.deployments[index] = d }
                } else if case let .deployment(d) = record {
                    k8s.deployments.append(d)
                }
            case .removed:
                k8s.deployments.removeAll { $0.id == id }
            }
        }
        k8s.collectedAt = Date()
        backendSnapshot?.kubernetes = k8s
    }

    // MARK: - Tool check timer

    /// Slow timer (60s) that re-probes tool presence/version when the event bus is active.
    /// Replaces the per-tick `toolChecks` that ran on every refresh.
    func runToolCheckTimer() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }
            guard useEventBus else { continue }
            await probeTools()
        }
    }

    private func probeTools() async {
        let report = await colima.diagnostics(profile: selectedProfileID)
        diagnostics = report
        hasCompletedDiagnostics = true
    }

    // MARK: - Monitor history

    private func appendMonitorSample(from snapshot: ColimaBackendSnapshot) {
        appendRuntimeUsageSample(snapshot.runtimeUsageSample())
    }

    private func appendRuntimeUsageSample(_ sample: RuntimeUsageSample) {
        monitorHistory.append(sample)
        trimMonitorHistory(forProfileID: sample.profileID)
    }

    private func trimMonitorHistory(forProfileID profileID: String) {
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
    static let useStreamingCommandOutput = "useStreamingCommandOutput"
    static let useEventBus = "useEventBus"
    static let tableDensity = "tableDensity"
}

struct AppError: Identifiable, Equatable {
    let id = UUID()
    var message: String
}
