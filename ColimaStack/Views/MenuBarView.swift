import AppKit
import SwiftUI

struct ColimaStackMenuBarLabel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Image(systemName: symbol)
            .accessibilityLabel(accessibilityLabel)
    }

    private var symbol: String {
        switch appState.selectedProfile?.state ?? appState.diagnostics.colima.state {
        case .running:
            return "cube.transparent.fill"
        case .starting, .stopping:
            return "arrow.triangle.2.circlepath"
        case .stopped:
            return "cube.transparent"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .broken:
            return "xmark.octagon.fill"
        case .unknown:
            return "questionmark.circle"
        }
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
        statusSection
        Divider()

        Button("Open ColimaStack", systemImage: "macwindow") {
            openMainWindow()
        }

        Button("Refresh", systemImage: "arrow.clockwise") {
            Task { await appState.refreshAll() }
        }
        .disabled(appState.isRefreshing)

        Toggle(isOn: $appState.autoRefresh) {
            Label("Auto Refresh", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
        }

        Divider()
        profilesMenu
        selectedProfileMenu
        dockerResourcesMenu
        kubernetesMenu
        diagnosticsMenu

        Divider()
        Button("Settings...", systemImage: "gearshape") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("About ColimaStack", systemImage: "info.circle") {
            NSApp.orderFrontStandardAboutPanel(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit ColimaStack", systemImage: "power") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusSection: some View {
        Section {
            if let activeOperation = appState.activeOperation {
                Label(activeOperation, systemImage: "bolt.horizontal.circle")
            } else if appState.isRefreshing {
                Label("Refreshing runtime data", systemImage: "arrow.clockwise")
            } else if let profile = appState.selectedProfile {
                Label("\(profile.name) - \(profile.state.label)", systemImage: symbol(for: profile.state))
                if let runtime = profile.runtime {
                    Label(runtime.label, systemImage: "cpu")
                }
                if !profile.dockerContext.isEmpty {
                    Label(profile.dockerContext, systemImage: "point.3.connected.trianglepath.dotted")
                }
            } else if appState.hasColima {
                Label("No active profile", systemImage: "cube.transparent")
            } else {
                Label("Colima setup required", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var profilesMenu: some View {
        Menu {
            if appState.profiles.isEmpty {
                Button("Create Profile...", systemImage: "plus") {
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
                        Button("Edit Profile...", systemImage: "slider.horizontal.3") {
                            select(profile)
                            openMainWindow()
                            appState.editSelectedProfile()
                        }

                        if !profile.dockerContext.isEmpty {
                            Button("Copy Docker Context", systemImage: "doc.on.doc") {
                                copy(profile.dockerContext)
                            }
                        }

                        if !profile.socket.isEmpty {
                            Button("Copy Socket Path", systemImage: "doc.on.doc") {
                                copy(profile.socket)
                            }
                        }

                        Button("Reveal Profile Folder", systemImage: "folder") {
                            reveal(profile.configurationPaths.profileConfiguration)
                        }
                    } label: {
                        Label("\(selectedPrefix(for: profile))\(profile.name) - \(profile.state.label)", systemImage: symbol(for: profile.state))
                    }
                }

                Divider()
                Button("Create Profile...", systemImage: "plus") {
                    openMainWindow()
                    appState.createProfile()
                }
            }
        } label: {
            Label("Profiles", systemImage: "person.2")
        }
    }

    private var selectedProfileMenu: some View {
        Menu {
            if let profile = appState.selectedProfile {
                profileLifecycleButtons(for: profile)

                Divider()
                Button("Update Profile", systemImage: "arrow.down.circle") {
                    Task { await appState.updateSelected() }
                }
                .disabled(appState.activeOperation != nil)

                Button("Edit Profile...", systemImage: "slider.horizontal.3") {
                    openMainWindow()
                    appState.editSelectedProfile()
                }

                Divider()
                if !appState.logs.isEmpty {
                    Button("Open Activity Logs", systemImage: "doc.plaintext") {
                        openMainWindow(section: .activity)
                    }
                }

                Button("Reveal Profile Folder", systemImage: "folder") {
                    reveal(profile.configurationPaths.profileConfiguration)
                }
            } else {
                Button("Create Profile...", systemImage: "plus") {
                    openMainWindow()
                    appState.createProfile()
                }
            }
        } label: {
            Label("Selected Profile", systemImage: "cube.transparent")
        }
    }

    private var dockerResourcesMenu: some View {
        Menu {
            if let docker = appState.backendSnapshot?.docker {
                containersMenu(containers: docker.containers)
                portsMenu(containers: docker.containers)
                mountsMenu(volumes: docker.volumes)

                Divider()
                Button("Open Containers", systemImage: "shippingbox") {
                    openMainWindow(section: .containers)
                }
                Button("Open Images", systemImage: "square.stack.3d.up") {
                    openMainWindow(section: .images)
                }
                Button("Open Volumes", systemImage: "externaldrive") {
                    openMainWindow(section: .volumes)
                }
            } else {
                Button("Open Runtime View", systemImage: "shippingbox") {
                    openMainWindow(section: .containers)
                }
                .disabled(appState.selectedProfile == nil)
            }
        } label: {
            Label("Docker Resources", systemImage: "shippingbox")
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

                        Button("Open Containers View", systemImage: "shippingbox") {
                            openMainWindow(section: .containers)
                        }

                        Button("Copy Container ID", systemImage: "doc.on.doc") {
                            copy(container.id)
                        }

                        Button("Copy Image", systemImage: "doc.on.doc") {
                            copy(container.image)
                        }

                        if !container.ports.isEmpty {
                            Button("Copy Ports", systemImage: "doc.on.doc") {
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
            Label("Containers", systemImage: "shippingbox")
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
                        Button(displayMountPoint(for: mount), systemImage: "folder") {
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

    private var kubernetesMenu: some View {
        Menu {
            if let profile = appState.selectedProfile {
                Button(profile.kubernetes.enabled ? "Disable Kubernetes" : "Enable Kubernetes", systemImage: "hexagon") {
                    Task { await appState.setKubernetes(enabled: !profile.kubernetes.enabled) }
                }
                .disabled(appState.activeOperation != nil)

                Button("Restart Profile", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await appState.restartSelected() }
                }
                .disabled(appState.activeOperation != nil)

                Divider()
                if let kubernetes = appState.backendSnapshot?.kubernetes {
                    Label("\(kubernetes.nodes.count) nodes", systemImage: "server.rack")
                    Label("\(kubernetes.pods.count) pods", systemImage: "rectangle.3.group")
                    Label("\(kubernetes.services.count) services", systemImage: "point.3.connected.trianglepath.dotted")
                    Divider()
                }

                Button("Open Cluster", systemImage: "server.rack") {
                    openMainWindow(section: .kubernetesCluster)
                }
                Button("Open Workloads", systemImage: "rectangle.3.group") {
                    openMainWindow(section: .kubernetesWorkloads)
                }
                Button("Open Services", systemImage: "point.3.connected.trianglepath.dotted") {
                    openMainWindow(section: .kubernetesServices)
                }
            } else {
                Text("No active profile")
            }
        } label: {
            Label("Kubernetes", systemImage: "hexagon")
        }
    }

    private var diagnosticsMenu: some View {
        Menu {
            Button("Run Checks", systemImage: "stethoscope") {
                Task { await appState.refreshAll() }
                openMainWindow(section: .diagnostics)
            }

            Button("Open Diagnostics", systemImage: "list.bullet.clipboard") {
                openMainWindow(section: .diagnostics)
            }

            Button("Open Activity", systemImage: "terminal") {
                openMainWindow(section: .activity)
            }

            Button("Copy Diagnostics Summary", systemImage: "doc.on.doc") {
                copy(diagnosticsSummary)
            }
        } label: {
            Label("Diagnostics", systemImage: "stethoscope")
        }
    }

    @ViewBuilder
    private func profileLifecycleButtons(for profile: ColimaProfile) -> some View {
        if profile.state == .running {
            Button("Stop", systemImage: "stop.fill") {
                select(profile)
                Task { await appState.stopSelected() }
            }
            .disabled(appState.activeOperation != nil)

            Button("Restart", systemImage: "arrow.triangle.2.circlepath") {
                select(profile)
                Task { await appState.restartSelected() }
            }
            .disabled(appState.activeOperation != nil)
        } else {
            Button("Start", systemImage: "play.fill") {
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

    private func symbol(for state: ProfileState) -> String {
        switch state {
        case .running:
            return "play.circle.fill"
        case .starting, .stopping:
            return "arrow.triangle.2.circlepath"
        case .stopped:
            return "stop.circle"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .broken:
            return "xmark.octagon.fill"
        case .unknown:
            return "questionmark.circle"
        }
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
        parseHostPorts(container.ports).map { port in
            let scheme = port == 443 ? "https" : "http"
            let url = URL(string: "\(scheme)://localhost:\(port)")!
            return MenuPortItem(id: "\(container.id)-\(port)", title: "\(container.name) - localhost:\(port)", url: url)
        }
    }

    private func parseHostPorts(_ ports: String) -> [Int] {
        let matches = ports.matches(of: /(?:0\.0\.0\.0|127\.0\.0\.1|\[::\]|::):([0-9]+)->/)
        return matches.compactMap { Int($0.1) }
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
