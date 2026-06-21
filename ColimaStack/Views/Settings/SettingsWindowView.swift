//
//  SettingsWindowView.swift
//  ColimaStack
//
//  Sidebar-style settings window with five categories. Replaces the
//  legacy `TabView`+`Form` implementation. Implements the
//  settings-window capability from the apple-design-award-ui change.
//

import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general
    case kubernetes
    case networking
    case integrations
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .kubernetes: return "Kubernetes"
        case .networking: return "Networking"
        case .integrations: return "Integrations"
        case .advanced: return "Advanced"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .kubernetes: return "hexagon"
        case .networking: return "network"
        case .integrations: return "link.badge.plus"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct SettingsWindowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPane: SettingsPane = .general
    @State private var confirmReset = false
    @AppStorage("settings.selectedPane") private var persistedPane: String = SettingsPane.general.rawValue

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selectedPane) { pane in
                Label(pane.title, systemImage: pane.symbol)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            SettingsPaneContent(pane: selectedPane)
                .environmentObject(appState)
        }
        .frame(minWidth: 720, minHeight: 560)
        .navigationTitle("ColimaStack Settings")
        .onAppear {
            if let stored = SettingsPane(rawValue: persistedPane) {
                selectedPane = stored
            }
        }
        .onChange(of: selectedPane) { _, pane in
            persistedPane = pane.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsPaneShortcut)) { note in
            if let raw = note.userInfo?["pane"] as? String, let pane = SettingsPane(rawValue: raw) {
                selectedPane = pane
            }
        }
        .alert("Reset configuration?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                appState.cancelProfileEditing()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will close the profile editor and revert any in-flight changes.")
        }
    }
}

struct SettingsPaneContent: View {
    @EnvironmentObject private var appState: AppState
    let pane: SettingsPane
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch pane {
                case .general:
                    generalCards
                case .kubernetes:
                    kubernetesCards
                case .networking:
                    networkingCards
                case .integrations:
                    integrationsCards
                case .advanced:
                    advancedCards
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Material.regular)
        .alert("Reset configuration?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                appState.cancelProfileEditing()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will close the profile editor and revert any in-flight changes.")
        }
    }

    private var generalCards: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "Refresh", subtitle: "Auto refresh and live event feeds.", symbol: "arrow.clockwise") {
                VStack(spacing: 10) {
                    EditorRow(label: "Auto refresh") {
                        Toggle("", isOn: $appState.autoRefresh)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    EditorRow(label: "Auto refresh frequency") {
                        Picker("", selection: $appState.autoRefreshFrequency) {
                            ForEach(AutoRefreshFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    EditorRow(label: "Live event feeds") {
                        Toggle("", isOn: $appState.useEventBus)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    EditorRow(label: "Stream command output") {
                        Toggle("", isOn: $appState.useStreamingCommandOutput)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            SectionCard(title: "Selected", subtitle: "Current selection state.", symbol: "person.text.rectangle") {
                KeyValueGrid(rows: [
                    ("Profile", appState.selectedProfile?.name ?? "None"),
                    ("Active section", appState.selectedSection.title),
                    ("Refresh state", appState.isRefreshing ? "Refreshing" : "Idle")
                ])
            }
            SectionCard(title: "About", subtitle: "Application version and metadata.", symbol: "info.circle") {
                KeyValueGrid(rows: [
                    ("Application", "ColimaStack"),
                    ("Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"),
                    ("Build", Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                ])
            }
        }
    }

    private var kubernetesCards: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "Status", subtitle: "Current Kubernetes configuration for the selected profile.", symbol: Icon.Kubernetes.enabled.symbolName) {
                KeyValueGrid(rows: [
                    ("Enabled", appState.selectedProfile?.kubernetes.enabled == true ? "Yes" : "No"),
                    ("Version", appState.selectedProfile?.kubernetes.version.nonEmpty ?? "Default"),
                    ("Context", appState.selectedProfile?.kubernetes.context.nonEmpty ?? "Unavailable")
                ])
            }
            SectionCard(title: "Actions", subtitle: "Toggle or edit the Kubernetes control plane.", symbol: "bolt.horizontal") {
                HStack {
                    Button(appState.selectedProfile?.kubernetes.enabled == true ? "Disable Kubernetes" : "Enable Kubernetes") {
                        Task { await appState.setKubernetes(enabled: appState.selectedProfile?.kubernetes.enabled != true) }
                    }
                    .disabled(appState.selectedProfile == nil || appState.activeOperation != nil)
                    Button("Edit Profile") {
                        appState.editSelectedProfile()
                    }
                    .disabled(appState.selectedProfile == nil)
                }
            }
        }
    }

    private var networkingCards: some View {
        SectionCard(title: "Endpoints", subtitle: "Network values for the selected profile.", symbol: "network") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(networkRows, id: \.label) { row in
                    HStack {
                        Text(row.label)
                            .font(.subheadline)
                            .frame(minWidth: 140, alignment: .leading)
                        Text(row.value.isEmpty ? "Unavailable" : row.value)
                            .font(.system(.subheadline, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if !row.value.isEmpty {
                            Button {
                                copyToPasteboard(row.value)
                            } label: {
                                Image(systemName: Icon.Action.copy.symbolName)
                            }
                            .buttonStyle(.borderless)
                            .help("Copy \(row.label)")
                        }
                    }
                }
            }
        }
    }

    private var integrationsCards: some View {
        SectionCard(title: "Toolchain", subtitle: "Detected command-line dependencies.", symbol: "wrench.and.screwdriver") {
            if appState.diagnostics.tools.isEmpty {
                SurfaceStateView(
                    title: "No tools detected",
                    message: "Run diagnostics to refresh the tool inventory.",
                    symbol: "wrench.and.screwdriver",
                    tone: .neutral
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.diagnostics.tools) { tool in
                        RedesignedToolRow(tool: tool)
                    }
                }
            }
        }
    }

    private var advancedCards: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "Profile actions", subtitle: "Update or restart the selected profile.", symbol: "arrow.triangle.2.circlepath") {
                HStack {
                    Button("Update Profile") {
                        Task { await appState.updateSelected() }
                    }
                    .disabled(appState.selectedProfile == nil || appState.activeOperation != nil)
                    Button("Restart Profile") {
                        Task { await appState.restartSelected() }
                    }
                    .disabled(appState.selectedProfile == nil || appState.activeOperation != nil)
                }
            }
            SectionCard(title: "Diagnostics", subtitle: "Run checks and inspect local state.", symbol: "stethoscope") {
                HStack {
                    Button("Run Diagnostics") {
                        Task { await appState.refreshAll() }
                    }
                    .disabled(appState.isRefreshing)
                    Button("Reset Configuration", role: .destructive) {
                        confirmReset = true
                    }
                }
                KeyValueGrid(rows: [
                    ("Command history", "\(appState.commandLog.count) entries"),
                    ("Logs captured", appState.logs.isEmpty ? "No" : "Yes"),
                    ("Diagnostics messages", "\(appState.diagnostics.messages.count)")
                ])
            }
        }
    }

    private struct NetworkRow {
        let label: String
        let value: String
    }

    private var networkRows: [NetworkRow] {
        let detail = appState.selectedProfileDetail ?? appState.selectedProfile?.statusDetail
        return [
            NetworkRow(label: "Docker context", value: detail?.dockerContext ?? appState.selectedProfile?.dockerContext ?? ""),
            NetworkRow(label: "Address", value: detail?.networkAddress ?? appState.selectedProfile?.ipAddress ?? ""),
            NetworkRow(label: "Socket", value: detail?.socket ?? appState.selectedProfile?.socket ?? ""),
            NetworkRow(label: "Mount type", value: appState.selectedProfile?.mountType?.label ?? ""),
            NetworkRow(label: "Kubernetes context", value: appState.selectedProfile?.kubernetes.context ?? "")
        ]
    }
}

// MARK: - Redesigned tool row

struct RedesignedToolRow: View {
    let tool: ToolCheck

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer()
            if case .available(let path, _) = tool.availability, !path.isEmpty {
                Button {
                    copyToPasteboard(path)
                } label: {
                    Image(systemName: Icon.Action.copy.symbolName)
                }
                .buttonStyle(.borderless)
                .help("Copy path")
            }
        }
        .padding(.vertical, 4)
    }

    private var detail: String {
        switch tool.availability {
        case .available(let path, let version):
            [path, version].compactMap { $0 }.joined(separator: " · ")
        case .missing:
            "Not found on PATH"
        case .error(let message):
            message
        }
    }

    private var symbol: String {
        switch tool.availability {
        case .available: return "checkmark.circle.fill"
        case .missing: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch tool.availability {
        case .available: return .green
        case .missing: return .red
        case .error: return .orange
        }
    }
}
