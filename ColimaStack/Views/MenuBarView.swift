//
//  MenuBarView.swift
//  ColimaStack
//
//  Menu bar: single-color profile status mark, structured menu
//  (status header · Open · Refresh · Auto Refresh · profile · runtime
//  · kubernetes · diagnostics · app), live-updates via the existing
//  event bus. Part of the workspace-chrome capability.
//

import AppKit
import SwiftUI

struct ColimaStackMenuBarLabel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let state = appState.selectedProfile?.state ?? appState.diagnostics.colima.state
        let symbol = Icon.Profile.forState(state)
        return Image(systemName: symbol.symbolName)
            .foregroundStyle(Icon.Profile.tint(for: state))
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let profile = appState.selectedProfile else {
            return "ColimaStack"
        }
        return "ColimaStack \(profile.name) \(profile.state.label)"
    }
}

struct ColimaStackMenuBarMenu: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    let openMainWindow: () -> Void

    var body: some View {
        statusHeader
        Divider()

        Button("Open ColimaStack", systemImage: Icon.Action.open.symbolName) {
            openMainWindow()
        }
        .keyboardShortcut("0", modifiers: [.command])

        Button("Refresh Now", systemImage: Icon.Action.refresh.symbolName) {
            Task { await appState.refreshAll() }
        }
        .disabled(appState.isRefreshing)
        .keyboardShortcut("r", modifiers: [.command])

        Toggle(isOn: $appState.autoRefresh) {
            Label("Auto Refresh", systemImage: Icon.Action.autoRefresh.symbolName)
        }

        Divider()
        profileSection
        runtimeSection
        kubernetesSection
        diagnosticsSection

        Divider()
        Button("Settings...", systemImage: Icon.Action.settings.symbolName) {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: [.command])

        Button("About ColimaStack", systemImage: Icon.Action.about.symbolName) {
            NSApp.orderFrontStandardAboutPanel(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit ColimaStack", systemImage: Icon.Action.quit.symbolName) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }

    // MARK: - Status header

    private var statusHeader: some View {
        Section {
            if let activeOperation = appState.activeOperation {
                Label(activeOperation, systemImage: "bolt.horizontal.circle")
            } else if appState.isRefreshing {
                Label("Refreshing runtime data", systemImage: Icon.Action.refresh.symbolName)
            } else if let profile = appState.selectedProfile {
                Label(profile.name, systemImage: Icon.Profile.forState(profile.state).symbolName)
                Label(profile.state.label, systemImage: "circle.fill")
                    .foregroundStyle(Icon.Profile.tint(for: profile.state))
                if let runtime = profile.runtime {
                    Label(runtime.label, systemImage: "cpu")
                }
                if !profile.dockerContext.isEmpty {
                    Label(profile.dockerContext, systemImage: "point.3.connected.trianglepath.dotted")
                }
                if appState.useEventBus {
                    connectionStatusLabels
                }
            } else if appState.hasColima {
                Label("No active profile", systemImage: "shippingbox")
            } else {
                Label("Colima setup required", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var connectionStatusLabels: some View {
        Group {
            if appState.connectionStatus.docker != .connected {
                Label(connectionLabel(for: appState.connectionStatus.docker, name: "Docker"), systemImage: connectionSymbol(for: appState.connectionStatus.docker))
            }
            if appState.connectionStatus.kubernetes != .connected {
                Label(connectionLabel(for: appState.connectionStatus.kubernetes, name: "Kubernetes"), systemImage: connectionSymbol(for: appState.connectionStatus.kubernetes))
            }
            if appState.connectionStatus.colima != .connected {
                Label(connectionLabel(for: appState.connectionStatus.colima, name: "Colima"), systemImage: connectionSymbol(for: appState.connectionStatus.colima))
            }
        }
    }

    private func connectionLabel(for state: ConnectionState, name: String) -> String {
        switch state {
        case .connected: return "\(name) connected"
        case .disconnected: return "\(name) disconnected"
        case .connecting: return "\(name) connecting…"
        case .reconnecting(let attempt): return "\(name) reconnecting (attempt \(attempt))"
        case .failed(let reason): return "\(name) failed: \(reason)"
        }
    }

    private func connectionSymbol(for state: ConnectionState) -> String {
        switch state {
        case .connected: return "checkmark.circle"
        case .disconnected: return "circle.slash"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .reconnecting: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.triangle"
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Menu {
            if appState.profiles.isEmpty {
                Button("Create Profile...", systemImage: Icon.Action.add.symbolName) {
                    openMainWindow()
                    appState.createProfile()
                }
            } else {
                ForEach(appState.profiles) { profile in
                    Menu {
                        Button(profile.id == appState.selectedProfileID ? "Selected" : "Select", systemImage: "checkmark.circle") {
                            select(profile)
                        }
                        .disabled(profile.id == appState.selectedProfileID)

                        Divider()
                        profileLifecycleButtons(for: profile)

                        Divider()
                        Button("Edit Profile...", systemImage: Icon.Action.edit.symbolName) {
                            select(profile)
                            openMainWindow()
                            appState.editSelectedProfile()
                        }

                        if !profile.dockerContext.isEmpty {
                            Button("Copy Docker Context", systemImage: Icon.Action.copy.symbolName) {
                                copy(profile.dockerContext)
                            }
                        }

                        if !profile.socket.isEmpty {
                            Button("Copy Socket Path", systemImage: Icon.Action.copy.symbolName) {
                                copy(profile.socket)
                            }
                        }

                        Button("Reveal Profile Folder", systemImage: Icon.Action.reveal.symbolName) {
                            reveal(profile.configurationPaths.profileConfiguration)
                        }
                    } label: {
                        Label("\(selectedPrefix(for: profile))\(profile.name)", systemImage: Icon.Profile.forState(profile.state).symbolName)
                    }
                }

                Divider()
                Button("Create Profile...", systemImage: Icon.Action.add.symbolName) {
                    openMainWindow()
                    appState.createProfile()
                }
            }
        } label: {
            Label("Profiles", systemImage: Icon.Section.profiles.symbolName)
        }
    }

    private var runtimeSection: some View {
        Menu {
            if let docker = appState.backendSnapshot?.docker {
                containersMenu(containers: docker.containers)
                portsMenu(containers: docker.containers)
                mountsMenu(volumes: docker.volumes)

                Divider()
                Button("Open Containers", systemImage: Icon.Runtime.docker.symbolName) {
                    openMainWindow(section: .containers)
                }
                Button("Open Images", systemImage: "square.stack.3d.up") {
                    openMainWindow(section: .images)
                }
                Button("Open Volumes", systemImage: "externaldrive") {
                    openMainWindow(section: .volumes)
                }
            } else {
                Button("Open Runtime View", systemImage: Icon.Runtime.docker.symbolName) {
                    openMainWindow(section: .containers)
                }
                .disabled(appState.selectedProfile == nil)
            }
        } label: {
            Label("Runtime", systemImage: Icon.Section.runtime.symbolName)
        }
    }

    private var kubernetesSection: some View {
        Menu {
            if let profile = appState.selectedProfile {
                Button(profile.kubernetes.enabled ? "Disable Kubernetes" : "Enable Kubernetes", systemImage: Icon.Kubernetes.enabled.symbolName) {
                    Task { await appState.setKubernetes(enabled: !profile.kubernetes.enabled) }
                }
                .disabled(appState.activeOperation != nil)

                Button("Restart Profile", systemImage: Icon.Action.restart.symbolName) {
                    Task { await appState.restartSelected() }
                }
                .disabled(appState.activeOperation != nil)

                Divider()
                if let kubernetes = appState.backendSnapshot?.kubernetes {
                    Label("\(kubernetes.nodes.count) nodes", systemImage: Icon.Kubernetes.cluster.symbolName)
                    Label("\(kubernetes.pods.count) pods", systemImage: Icon.Kubernetes.workloads.symbolName)
                    Label("\(kubernetes.services.count) services", systemImage: Icon.Kubernetes.services.symbolName)
                    Divider()
                }

                Button("Open Cluster", systemImage: Icon.Kubernetes.cluster.symbolName) {
                    openMainWindow(section: .kubernetesCluster)
                }
                Button("Open Workloads", systemImage: Icon.Kubernetes.workloads.symbolName) {
                    openMainWindow(section: .kubernetesWorkloads)
                }
                Button("Open Services", systemImage: Icon.Kubernetes.services.symbolName) {
                    openMainWindow(section: .kubernetesServices)
                }
            } else {
                Text("No active profile")
            }
        } label: {
            Label("Kubernetes", systemImage: Icon.Section.kubernetes.symbolName)
        }
    }

    private var diagnosticsSection: some View {
        Menu {
            Button("Run Checks", systemImage: Icon.Action.diagnostics.symbolName) {
                Task { await appState.refreshAll() }
                openMainWindow(section: .diagnostics)
            }

            Button("Open Diagnostics", systemImage: Icon.Action.diagnostics.symbolName) {
                openMainWindow(section: .diagnostics)
            }

            Button("Open Activity", systemImage: Icon.Action.terminal.symbolName) {
                openMainWindow(section: .activity)
            }

            Button("Copy Diagnostics Summary", systemImage: Icon.Action.copy.symbolName) {
                copy(diagnosticsSummary)
            }
        } label: {
            Label("Diagnostics", systemImage: Icon.Action.diagnostics.symbolName)
        }
    }

    private func containersMenu(containers: [DockerContainerResource]) -> some View {
        Menu {
            if containers.isEmpty {
                Text("No containers reported")
            } else {
                ForEach(containers.prefix(12)) { container in
                    Menu {
                        if let url = firstURL(for: container) {
                            Button("Open in Browser", systemImage: "safari") {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        Button("Open Containers View", systemImage: Icon.Runtime.docker.symbolName) {
                            openMainWindow(section: .containers)
                        }

                        Button("Copy Container ID", systemImage: Icon.Action.copy.symbolName) {
                            copy(container.id)
                        }

                        Button("Copy Image", systemImage: Icon.Action.copy.symbolName) {
                            copy(container.image)
                        }

                        if !container.ports.isEmpty {
                            Button("Copy Ports", systemImage: Icon.Action.copy.symbolName) {
                                copy(container.ports)
                            }
                        }
                    } label: {
                        Label(container.name, systemImage: container.state.lowercased() == "running" ? "play.circle" : "stop.circle")
                    }
                }

                if containers.count > 12 {
                    Divider()
                    Button("Show All Containers", systemImage: "ellipsis.circle") {
                        openMainWindow(section: .containers)
                    }
                }
            }
        } label: {
            Label("Containers", systemImage: Icon.Runtime.docker.symbolName)
        }
    }

    private func portsMenu(containers: [DockerContainerResource]) -> some View {
        Menu {
            let ports = containers.flatMap(portItems)
            if ports.isEmpty {
                Text("No published ports reported")
            } else {
                ForEach(ports.prefix(12)) { item in
                    Button(item.title, systemImage: "safari") {
                        NSWorkspace.shared.open(item.url)
                    }
                }

                if ports.count > 12 {
                    Divider()
                    Button("Show All Containers", systemImage: "ellipsis.circle") {
                        openMainWindow(section: .containers)
                    }
                }
            }
        } label: {
            Label("Ports & Services", systemImage: "network")
        }
    }

    private func mountsMenu(volumes: [DockerVolumeResource]) -> some View {
        Menu {
            let profileMounts = appState.selectedProfile?.mounts ?? []
            if profileMounts.isEmpty, volumes.isEmpty {
                Text("No mounts or volumes reported")
            }

            if !profileMounts.isEmpty {
                Section("Profile Mounts") {
                    ForEach(profileMounts.prefix(8)) { mount in
                        Button(displayMountPoint(for: mount), systemImage: Icon.Action.reveal.symbolName) {
                            reveal(URL(fileURLWithPath: mount.location))
                        }
                    }
                }
            }

            if !volumes.isEmpty {
                Section("Docker Volumes") {
                    ForEach(volumes.prefix(8)) { volume in
                        Button(volume.name, systemImage: "externaldrive") {
                            copy(volume.mountpoint)
                        }
                    }
                }
            }

            Divider()
            Button("Open Volumes View", systemImage: "externaldrive") {
                openMainWindow(section: .volumes)
            }
        } label: {
            Label("Volumes & Mounts", systemImage: "externaldrive")
        }
    }

    @ViewBuilder
    private func profileLifecycleButtons(for profile: ColimaProfile) -> some View {
        if profile.state == .running {
            Button("Stop", systemImage: Icon.Action.stop.symbolName) {
                select(profile)
                Task { await appState.stopSelected() }
            }
            .disabled(appState.activeOperation != nil)

            Button("Restart", systemImage: Icon.Action.restart.symbolName) {
                select(profile)
                Task { await appState.restartSelected() }
            }
            .disabled(appState.activeOperation != nil)
        } else {
            Button("Start", systemImage: Icon.Action.start.symbolName) {
                select(profile)
                Task { await appState.startSelected() }
            }
            .disabled(appState.activeOperation != nil)
        }
    }

    private func select(_ profile: ColimaProfile) {
        appState.selectedProfileID = profile.id
        Task { await appState.refreshProfile(profile.id) }
    }

    private func openMainWindow(section: WorkspaceRoute? = nil) {
        if let section {
            appState.selectedSection = section
        }
        openMainWindow()
    }

    private func selectedPrefix(for profile: ColimaProfile) -> String {
        profile.id == appState.selectedProfileID ? "Selected: " : ""
    }

    private func displayMountPoint(for mount: ColimaMount) -> String {
        let mountPoint = mount.mountPoint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return mountPoint.isEmpty ? mount.location : mountPoint
    }

    private func firstURL(for container: DockerContainerResource) -> URL? {
        portItems(for: container).first?.url
    }

    private func portItems(for container: DockerContainerResource) -> [MenuPortItem] {
        container.portBindings.compactMap { binding in
            guard let url = binding.browserURL else { return nil }
            return MenuPortItem(
                id: "\(container.id)-\(binding.hostPort)-\(binding.proto)",
                title: "\(container.name) - localhost:\(binding.hostPort)",
                url: url
            )
        }
    }

    private var diagnosticsSummary: String {
        var lines: [String] = []
        lines.append("ColimaStack diagnostics")
        lines.append("Profile: \(appState.selectedProfile?.name ?? "none")")
        lines.append("Colima: \(appState.diagnostics.colima.state.label)")
        lines.append("Docker available: \(appState.diagnostics.docker.available ? "yes" : "no")")
        if !appState.diagnostics.docker.context.isEmpty {
            lines.append("Docker context: \(appState.diagnostics.docker.context)")
        }
        if let snapshot = appState.backendSnapshot {
            lines.append("Containers: \(snapshot.docker?.containers.count ?? 0)")
            lines.append("Kubernetes nodes: \(snapshot.kubernetes?.nodes.count ?? 0)")
            lines.append("Issues: \(snapshot.issues.count)")
        }
        return lines.joined(separator: "\n")
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

private struct MenuPortItem: Identifiable {
    var id: String
    var title: String
    var url: URL
}
