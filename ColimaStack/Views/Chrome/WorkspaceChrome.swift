//
//  WorkspaceChrome.swift
//  ColimaStack
//
//  Workspace chrome: native NSToolbar, sidebar, search, branding, and
//  runtime health footer. Implements the workspace-chrome capability
//  from the apple-design-award-ui change. This is the single source of
//  truth for the main window's chrome; the legacy `MainWindowView` body
//  forwards into `WorkspaceChrome`.
//

import AppKit
import SwiftUI

// MARK: - WorkspaceChrome

/// The chrome for the main workspace window. Renders the sidebar,
/// toolbar, search, and runtime health footer.
struct WorkspaceChrome<Detail: View>: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @Binding var searchText: String
    @State private var inspectContainerID: String?
    @State private var logsContainerID: String?
    let detail: () -> Detail

    init(searchText: Binding<String>, @ViewBuilder detail: @escaping () -> Detail) {
        self._searchText = searchText
        self.detail = detail
    }

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            detail()
                .environmentObject(appState)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 360)
        .frame(minWidth: 920, minHeight: 620)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search \(appState.selectedSection.searchScopeLabel)")
        .toolbar { toolbarContent }
        .sheet(isPresented: profileEditorBinding) {
            ProfileEditorView()
                .environmentObject(appState)
                .frame(minWidth: 720, minHeight: 760)
        }
        .sheet(item: Binding(
            get: { inspectContainerID.map(IdentifiedString.init) },
            set: { inspectContainerID = $0?.value }
        )) { identified in
            ContainerInspectSheet(containerID: identified.value)
        }
        .sheet(item: Binding(
            get: { logsContainerID.map(IdentifiedString.init) },
            set: { logsContainerID = $0?.value }
        )) { identified in
            ContainerLogsSheet(containerID: identified.value)
        }
        .alert(item: $appState.presentedError) { error in
            Alert(title: Text("ColimaStack"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .background(WindowAccessor())
        .onReceive(NotificationCenter.default.publisher(for: .presentContainerInspect)) { note in
            if let id = note.object as? String { inspectContainerID = id }
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentContainerLogs)) { note in
            if let id = note.object as? String { logsContainerID = id }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                Task { await appState.refreshAll() }
            } label: {
                Label("Refresh", systemImage: Icon.Action.refresh.symbolName)
            }
            .help("Refresh runtime and Kubernetes data")
            .accessibilityIdentifier("toolbar.refresh")
            .disabled(appState.isRefreshing)
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    Task { await appState.startSelected() }
                } label: {
                    Label("Start", systemImage: Icon.Action.start.symbolName)
                }
                .help("Start the selected profile")
                .accessibilityIdentifier("toolbar.start")

                Button {
                    Task { await appState.stopSelected() }
                } label: {
                    Label("Stop", systemImage: Icon.Action.stop.symbolName)
                }
                .help("Stop the selected profile")
                .accessibilityIdentifier("toolbar.stop")

                Button {
                    Task { await appState.restartSelected() }
                } label: {
                    Label("Restart", systemImage: Icon.Action.restart.symbolName)
                }
                .help("Restart the selected profile")
                .accessibilityIdentifier("toolbar.restart")

                Button(role: .destructive) {
                    beginDeleteConfirmation()
                } label: {
                    Label("Delete", systemImage: Icon.Action.delete.symbolName)
                }
                .help("Delete the selected profile")
                .accessibilityIdentifier("toolbar.delete")
            }
            .disabled(appState.selectedProfile == nil || appState.activeOperation != nil)
        }

        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $appState.autoRefresh) {
                Label("Auto Refresh", systemImage: Icon.Action.autoRefresh.symbolName)
            }
            .toggleStyle(.button)
            .help("Toggle automatic refresh")
            .accessibilityIdentifier("toolbar.autoRefresh")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                appState.selectedSection = .diagnostics
                Task { await appState.refreshAll() }
            } label: {
                Label("Run Diagnostics", systemImage: Icon.Action.diagnostics.symbolName)
            }
            .help("Run health checks and refresh diagnostics")
            .accessibilityIdentifier("toolbar.runDiagnostics")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: Icon.Action.settings.symbolName)
            }
            .help("Open settings (⌘,)")
            .accessibilityIdentifier("toolbar.settings")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                NSApp.orderFrontStandardAboutPanel(nil)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("About", systemImage: Icon.Action.about.symbolName)
            }
            .help("About ColimaStack")
            .accessibilityIdentifier("toolbar.about")
        }

        ToolbarItem(placement: .status) {
            if let activeOperation = appState.activeOperation {
                HStack(spacing: 6) {
                    Label(activeOperation, systemImage: "bolt.horizontal.circle")
                        .foregroundStyle(.secondary)
                        .help(activeOperation)
                    Button {
                        appState.cancelCurrentCommand()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Cancel the running command")
                    .accessibilityIdentifier("toolbar.cancelCommand")
                }
            }
        }
    }

    // MARK: - Profile editor binding & delete confirmation

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

    private func beginDeleteConfirmation() {
        // Surfaced via the destructive Delete toolbar button. The
        // confirm-by-typing flow is presented through
        // `MainWindowView.deleteProfileAlert`. We post a notification
        // so the legacy owner can present its alert; in the
        // long-running migration the alert moves here.
        NotificationCenter.default.post(
            name: .workspaceChromeRequestDeleteConfirmation,
            object: appState.selectedProfile
        )
    }
}

extension Notification.Name {
    static let workspaceChromeRequestDeleteConfirmation = Notification.Name("workspaceChromeRequestDeleteConfirmation")
}

/// Wraps a String as Identifiable for use with `.sheet(item:)`.
struct IdentifiedString: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Sidebar

/// The sidebar. Header (brand + tagline + selected profile summary) +
/// route sections + profile roster + runtime health footer. No
/// `navigationTitle`; the window title is the single source of truth.
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        List(selection: $appState.selectedSection) {
            Section {
                SidebarHeader()
            }

            routeSection(title: "Workspace", routes: [.overview, .profiles, .activity], sectionIcon: Icon.Section.workspace)
            routeSection(title: "Runtime", routes: [.containers, .images, .volumes, .networks, .monitor], sectionIcon: Icon.Section.runtime)
            routeSection(title: "Kubernetes", routes: [.kubernetesCluster, .kubernetesWorkloads, .kubernetesServices], sectionIcon: Icon.Section.kubernetes)

            Section {
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: Icon.Action.settings.symbolName)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("route.settings")

                Label(WorkspaceRoute.diagnostics.title, systemImage: WorkspaceRoute.diagnostics.symbol)
                    .accessibilityIdentifier("route.\(WorkspaceRoute.diagnostics.rawValue)")
                    .tag(WorkspaceRoute.diagnostics)
            } header: {
                HStack {
                    Icon.Section.support.iconRow()
                    Text("Support")
                }
            }

            profileRosterSection
        }
        .listStyle(.sidebar)
    }

    private func routeSection(title: String, routes: [WorkspaceRoute], sectionIcon: IconView) -> some View {
        Section {
            ForEach(routes) { route in
                Label(route.title, systemImage: route.symbol)
                    .accessibilityIdentifier("route.\(route.rawValue)")
                    .tag(route)
            }
        } header: {
            HStack(spacing: 6) {
                sectionIcon.iconRow()
                Text(title)
            }
        }
    }

    private var profileRosterSection: some View {
        Section {
            if appState.profiles.isEmpty {
                EmptyStateView(kind: .noData, title: "No profiles yet", message: "Create a profile to get started.", symbol: "rectangle.stack")
            } else {
                ForEach(appState.profiles) { profile in
                    Button {
                        selectProfile(profile)
                    } label: {
                        HStack(spacing: 10) {
                            Icon.Profile.forState(profile.state).iconRow()
                                .foregroundStyle(Icon.Profile.tint(for: profile.state))
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
                                Icon.Kubernetes.enabled.iconControl()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            profile.id == appState.selectedProfileID
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Icon.Section.profiles.iconRow()
                Text("Profiles")
                Spacer()
                Button {
                    appState.createProfile()
                } label: {
                    Image(systemName: Icon.Action.add.symbolName)
                }
                .buttonStyle(.borderless)
                .help("Create Profile")
            }
        }

        // Footer rendered outside the List so it is always anchored at
        // the bottom; SwiftUI's List doesn't support a sticky footer
        // across all platforms.
        // Footer handled by `SidebarWithFooter` wrapper.
    }

    private func selectProfile(_ profile: ColimaProfile) {
        appState.selectedProfileID = profile.id
        if appState.selectedSection == .diagnostics {
            appState.selectedSection = .overview
        }
        Task { await appState.refreshProfile(profile.id) }
    }
}

// MARK: - Sidebar header

private struct SidebarHeader: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Icon.brand.iconRow()
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(selectedProfileSummary)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        if appState.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 12, height: 12)
                                .accessibilityLabel("Refreshing")
                        }
                    }
                    Text("Colima control plane")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var selectedProfileSummary: String {
        guard let selectedProfile = appState.selectedProfile else {
            if !appState.hasCollectedDiagnostics {
                return "Checking CLI setup"
            }
            return appState.hasColima ? "No profile selected" : "Setup required"
        }
        return selectedProfile.name
    }
}

// MARK: - Runtime health footer

/// Compact "All systems operational / Docker disconnected" footer.
struct RuntimeHealthFooter: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            healthIcon
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(headline)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private enum Health {
        case ok, degraded, failed
    }

    private var health: Health {
        let status = appState.connectionStatus
        if status.docker != .connected || status.kubernetes != .connected || status.colima != .connected {
            return .failed
        }
        if appState.selectedProfile?.state == .degraded {
            return .degraded
        }
        return .ok
    }

    private var headline: String {
        switch health {
        case .ok: return "All systems operational"
        case .degraded: return "Runtime degraded"
        case .failed: return "Disconnected"
        }
    }

    private var detail: String {
        switch health {
        case .ok:
            return appState.selectedProfile?.name ?? "No profile selected"
        case .degraded:
            return appState.selectedProfile?.state.label ?? "Check profile"
        case .failed:
            return disconnectSummary
        }
    }

    private var disconnectSummary: String {
        var components: [String] = []
        let status = appState.connectionStatus
        if status.docker != .connected {
            components.append("Docker")
        }
        if status.kubernetes != .connected {
            components.append("Kubernetes")
        }
        if status.colima != .connected {
            components.append("Colima")
        }
        if components.isEmpty { return "—" }
        return components.joined(separator: " · ") + " disconnected"
    }

    @ViewBuilder
    private var healthIcon: some View {
        switch health {
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .degraded:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .failed:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Window helper

/// Wraps the sidebar + runtime health footer in a vertical stack so
/// the footer is anchored to the bottom of the sidebar.
struct SidebarWithFooter<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
            Divider()
            RuntimeHealthFooter()
        }
    }
}

// MARK: - Focused values

/// A focused value used to find the current search-text binding from
/// the menu bar. ⌘F on the main window focuses the bound field.
struct SearchTextKey: FocusedValueKey {
    typealias Value = Binding<String>
}

struct WorkspaceFocusKey: FocusedValueKey {
    typealias Value = FocusTarget
}

final class FocusTarget {}

extension FocusedValues {
    var searchText: Binding<String>? {
        get { self[SearchTextKey.self] }
        set { self[SearchTextKey.self] = newValue }
    }

    var workspaceFocus: FocusTarget? {
        get { self[WorkspaceFocusKey.self] }
        set { self[WorkspaceFocusKey.self] = newValue }
    }
}

// MARK: - Window accessor

/// Bridges SwiftUI's hosted NSWindow to set the `unifiedCompact`
/// title-bar style and a sensible title. SwiftUI's `.toolbar` doesn't
/// expose the title-bar style directly; we wrap the view with a
/// transparent `NSViewRepresentable` that adjusts the host window.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = "ColimaStack"
            window.titlebarAppearsTransparent = false
            if #available(macOS 13.0, *) {
                window.toolbarStyle = .unifiedCompact
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if window.title != "ColimaStack" {
                window.title = "ColimaStack"
            }
            if #available(macOS 13.0, *) {
                window.toolbarStyle = .unifiedCompact
            }
        }
    }
}

// MARK: - Icon namespace helpers

extension IconView {
    func iconControl() -> AnyView {
        AnyView(self.font(.system(size: DesignSystem.IconSize.control, weight: .medium)))
    }
    func iconRow() -> AnyView {
        AnyView(self.font(.system(size: DesignSystem.IconSize.row, weight: .medium)))
    }
    func iconHero() -> AnyView {
        AnyView(self.font(.system(size: DesignSystem.IconSize.hero, weight: .medium)))
    }
}
