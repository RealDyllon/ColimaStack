import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var searchText = ""
    @State private var confirmDelete = false
    @State private var deleteTargetProfile: ColimaProfile?
    @State private var deleteConfirmationText = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            WorkspaceDetailRouter(route: appState.selectedSection, searchText: searchText)
                .environmentObject(appState)
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search \(appState.selectedSection.searchScopeLabel)")
        }
        .frame(minWidth: 900, minHeight: 640)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await appState.refreshAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh runtime and Kubernetes data")
                .accessibilityIdentifier("toolbar.refresh")
                .disabled(appState.isRefreshing)

                Divider()

                Button {
                    Task { await appState.startSelected() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .help("Start the selected profile")
                .accessibilityIdentifier("toolbar.start")
                .disabled(appState.selectedProfile == nil || appState.activeOperation != nil)

                Button {
                    Task { await appState.stopSelected() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .help("Stop the selected profile")
                .accessibilityIdentifier("toolbar.stop")
                .disabled(appState.selectedProfile == nil || appState.activeOperation != nil)

                Button {
                    Task { await appState.restartSelected() }
                } label: {
                    Label("Restart", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("Restart the selected profile")
                .accessibilityIdentifier("toolbar.restart")
                .disabled(appState.selectedProfile == nil || appState.activeOperation != nil)

                Button(role: .destructive) {
                    beginDeleteConfirmation()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete the selected profile")
                .accessibilityIdentifier("toolbar.delete")
                .disabled(appState.selectedProfile == nil || appState.activeOperation != nil)

                Divider()

                Toggle(isOn: $appState.autoRefresh) {
                    Label("Auto Refresh", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
                .toggleStyle(.button)
                .help("Toggle automatic refresh")
                .accessibilityIdentifier("toolbar.autoRefresh")
            }

            ToolbarItem {
                if let activeOperation = appState.activeOperation {
                    Label(activeOperation, systemImage: "bolt.horizontal.circle")
                        .foregroundStyle(.secondary)
                        .help(activeOperation)
                }
            }
        }
        .sheet(isPresented: profileEditorBinding) {
            ProfileEditorView()
                .environmentObject(appState)
                .frame(minWidth: 680, minHeight: 760)
        }
        .alert(item: $appState.presentedError) { error in
            Alert(title: Text("ColimaStack"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .alert(deleteConfirmationTitle, isPresented: $confirmDelete) {
            TextField(deleteConfirmationPrompt, text: $deleteConfirmationText)
                .accessibilityIdentifier("delete.confirmationText")
            Button(deleteConfirmationButtonTitle, role: .destructive) {
                let profileID = deleteTargetProfile?.id
                finishDeleteConfirmation()
                if let profileID {
                    Task { await appState.delete(profileID: profileID) }
                }
            }
            .disabled(!isDeleteConfirmationValid)
            .accessibilityIdentifier("delete.confirm")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("delete.cancel")
        } message: {
            Text(deleteConfirmationMessage)
        }
        .onChange(of: confirmDelete) { _, isPresented in
            if !isPresented {
                finishDeleteConfirmation()
            }
        }
    }

    private var sidebar: some View {
        List(selection: $appState.selectedSection) {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "cube.transparent")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("ColimaStack")
                                    .font(.headline)

                                if appState.isRefreshing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 12, height: 12)
                                        .accessibilityLabel("Refreshing")
                                }
                            }
                            Text(selectedProfileSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    if let activeOperation = appState.activeOperation {
                        Label(activeOperation, systemImage: "bolt.horizontal.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            routeSection(title: "Workspace", routes: [.overview, .profiles, .activity])
            routeSection(title: "Runtime", routes: [.containers, .images, .volumes, .networks, .monitor])
            routeSection(title: "Kubernetes", routes: [.kubernetesCluster, .kubernetesWorkloads, .kubernetesServices])
            supportSection

            Section {
                if appState.profiles.isEmpty {
                    Text("No profiles yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(appState.profiles) { profile in
                        Button {
                            selectProfile(profile)
                        } label: {
                            HStack(spacing: 10) {
                                StatusDot(state: profile.state)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Text(profile.runtime?.label ?? profile.state.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if profile.kubernetes.enabled {
                                    Image(systemName: "hexagon")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(profile.id == appState.selectedProfileID ? Color.accentColor.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                HStack {
                    Text("Profiles")
                    Spacer()
                    Button {
                        appState.createProfile()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Create Profile")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ColimaStack")
        .navigationSplitViewColumnWidth(min: 250, ideal: 280)
    }

    private func routeSection(title: String, routes: [WorkspaceRoute]) -> some View {
        Section(title) {
            ForEach(routes) { route in
                Label(route.title, systemImage: route.symbol)
                    .accessibilityIdentifier("route.\(route.rawValue)")
                    .tag(route)
            }
        }
    }

    private var supportSection: some View {
        Section("Support") {
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("route.settings")

            Label(WorkspaceRoute.diagnostics.title, systemImage: WorkspaceRoute.diagnostics.symbol)
                .accessibilityIdentifier("route.\(WorkspaceRoute.diagnostics.rawValue)")
                .tag(WorkspaceRoute.diagnostics)
        }
    }

    private var selectedProfileSummary: String {
        guard let selectedProfile = appState.selectedProfile else {
            if !appState.hasCollectedDiagnostics {
                return "Checking CLI setup"
            }
            return appState.hasColima ? "No active profile selected" : "CLI setup required"
        }
        return "\(selectedProfile.name) - \(selectedProfile.state.label)"
    }

    private var profileEditorBinding: Binding<Bool> {
        Binding(
            get: { appState.isShowingProfileEditor },
            set: { isPresented in
                if isPresented {
                    appState.isShowingProfileEditor = true
                } else {
                    appState.cancelProfileEditing()
                }
            }
        )
    }

    private var deleteProfileName: String {
        deleteTargetProfile?.name ?? "selected profile"
    }

    private var deleteConfirmationTitle: String {
        "Delete \(deleteProfileName)?"
    }

    private var deleteConfirmationPrompt: String {
        "Type \(deleteProfileName) to confirm"
    }

    private var deleteConfirmationMessage: String {
        "This permanently deletes the Colima profile named \(deleteProfileName), including its VM and data. This cannot be undone."
    }

    private var deleteConfirmationButtonTitle: String {
        "Delete \(deleteProfileName)"
    }

    private var isDeleteConfirmationValid: Bool {
        deleteConfirmationText == deleteTargetProfile?.name
    }

    private func beginDeleteConfirmation() {
        guard let selectedProfile = appState.selectedProfile else { return }
        deleteTargetProfile = selectedProfile
        deleteConfirmationText = ""
        confirmDelete = true
    }

    private func finishDeleteConfirmation() {
        deleteConfirmationText = ""
        deleteTargetProfile = nil
    }

    private func selectProfile(_ profile: ColimaProfile) {
        appState.selectedProfileID = profile.id
        if appState.selectedSection == .diagnostics {
            appState.selectedSection = .overview
        }
        Task { await appState.refreshProfile(profile.id) }
    }
}

struct ProfileEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var validationErrors: [String] = ProfileConfiguration.default.validationErrors
    @State private var isValidatingConfiguration = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Profile") {
                    TextField("Name", text: $appState.editingConfiguration.name)
                    Picker("Runtime", selection: $appState.editingConfiguration.runtime) {
                        ForEach(ColimaRuntime.allCases.filter { $0 != .unknown && $0 != .none }) { runtime in
                            Text(runtime.label).tag(runtime)
                        }
                    }
                    Picker("VM Type", selection: $appState.editingConfiguration.vmType) {
                        ForEach(VMType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    Picker("Architecture", selection: $appState.editingConfiguration.architecture) {
                        ForEach(CPUArchitecture.allCases) { architecture in
                            Text(architecture.label).tag(architecture)
                        }
                    }
                }

                Section("Resources") {
                    Stepper("CPU: \(appState.editingConfiguration.resources.cpu)", value: $appState.editingConfiguration.resources.cpu, in: 1...32)
                    Stepper("Memory: \(appState.editingConfiguration.resources.memoryGiB) GiB", value: $appState.editingConfiguration.resources.memoryGiB, in: 1...128)
                    Stepper("Disk: \(appState.editingConfiguration.resources.diskGiB) GiB", value: $appState.editingConfiguration.resources.diskGiB, in: 1...2048)
                }

                Section("Kubernetes") {
                    Toggle("Enable Kubernetes", isOn: $appState.editingConfiguration.kubernetes.enabled)
                    TextField("Kubernetes Version", text: $appState.editingConfiguration.kubernetes.version)
                    OptionalIntField(title: "K3s Listen Port", value: $appState.editingConfiguration.k3sListenPort)
                    TagListEditor(title: "K3s Args", values: $appState.editingConfiguration.k3sArgs)
                }

                Section("Network") {
                    Toggle("Expose VM Address", isOn: $appState.editingConfiguration.network.networkAddress)
                    Picker("Mode", selection: $appState.editingConfiguration.network.mode) {
                        Text("Shared").tag("shared")
                        Text("Bridged").tag("bridged")
                    }
                    TextField("Interface", text: $appState.editingConfiguration.network.interface)
                        .disabled(appState.editingConfiguration.network.mode == "shared")
                    TagListEditor(title: "DNS Resolvers", values: $appState.editingConfiguration.network.dnsResolvers)
                }

                Section("Mounts") {
                    Picker("Mount Driver", selection: $appState.editingConfiguration.mountType) {
                        ForEach(MountType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }

                    ForEach($appState.editingConfiguration.mounts) { $mount in
                        HStack {
                            TextField("Local Path", text: $mount.localPath)
                            TextField("VM Path", text: $mount.vmPath)
                            Toggle("Writable", isOn: $mount.writable)
                                .toggleStyle(.checkbox)
                            Button {
                                appState.editingConfiguration.mounts.removeAll { $0.id == mount.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button {
                        appState.editingConfiguration.mounts.append(MountConfiguration(localPath: "", vmPath: "", writable: true))
                    } label: {
                        Label("Add Mount", systemImage: "plus")
                    }
                }

                Section("Advanced") {
                    Picker("Port Forwarder", selection: $appState.editingConfiguration.portForwarder) {
                        ForEach(PortForwarder.allCases) { forwarder in
                            Text(forwarder.label).tag(forwarder)
                        }
                    }
                    Toggle("Rosetta", isOn: $appState.editingConfiguration.rosetta)
                        .disabled(appState.editingConfiguration.vmType != .vz || appState.editingConfiguration.architecture == .x86_64)
                    Toggle("Nested Virtualization", isOn: $appState.editingConfiguration.nestedVirtualization)
                        .disabled(appState.editingConfiguration.vmType != .vz)
                    TagListEditor(title: "Additional CLI Args", values: $appState.editingConfiguration.additionalArgs)
                }
            }
            .formStyle(.grouped)

            ValidationSummary(errors: validationErrors)

            Divider()

            HStack {
                Button("Cancel") {
                    appState.cancelProfileEditing()
                    dismiss()
                }
                Spacer()
                Button("Apply") {
                    Task { await appState.saveEditingConfiguration() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!validationErrors.isEmpty || isValidatingConfiguration || appState.activeOperation != nil)
            }
            .padding()
        }
        .task(id: appState.editingConfiguration) {
            await validate(configuration: appState.editingConfiguration)
        }
    }

    private func validate(configuration: ProfileConfiguration) async {
        isValidatingConfiguration = true
        validationErrors = configuration.validationErrors
        let errors = await configuration.validationErrorsCheckingFilesystem()
        guard !Task.isCancelled else { return }
        validationErrors = errors
        isValidatingConfiguration = false
    }
}

private struct ValidationSummary: View {
    let errors: [String]

    var body: some View {
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Resolve these profile settings before applying", systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                ForEach(errors, id: \.self) { error in
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
        }
    }
}

struct TagListEditor: View {
    let title: String
    @Binding var values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Button {
                    values.append("")
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            ForEach(values.indices, id: \.self) { index in
                HStack {
                    TextField(title, text: Binding(get: { values[index] }, set: { values[index] = $0 }))
                    Button {
                        values.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

struct OptionalIntField: View {
    let title: String
    @Binding var value: Int?

    var body: some View {
        TextField(
            title,
            text: Binding(
                get: { value.map(String.init) ?? "" },
                set: { value = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        )
    }
}

struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .environmentObject(PreviewSupport.appState)
    }
}
