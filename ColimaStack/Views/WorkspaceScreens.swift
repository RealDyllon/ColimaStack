import AppKit
import Charts
import SwiftUI

enum WorkspaceRoute: String, CaseIterable, Hashable, Identifiable {
    case overview
    case containers
    case images
    case volumes
    case networks
    case monitor
    case kubernetesCluster
    case kubernetesWorkloads
    case kubernetesServices
    case profiles
    case activity
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .containers: "Containers"
        case .images: "Images"
        case .volumes: "Volumes"
        case .networks: "Networks"
        case .monitor: "Monitor"
        case .kubernetesCluster: "Cluster"
        case .kubernetesWorkloads: "Workloads"
        case .kubernetesServices: "Services"
        case .profiles: "Profiles"
        case .activity: "Activity"
        case .diagnostics: "Diagnostics"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .containers: "shippingbox"
        case .images: "square.stack.3d.up"
        case .volumes: "externaldrive"
        case .networks: "network"
        case .monitor: "waveform.path.ecg"
        case .kubernetesCluster: "hexagon"
        case .kubernetesWorkloads: "square.3.layers.3d"
        case .kubernetesServices: "point.3.connected.trianglepath.dotted"
        case .profiles: "rectangle.stack"
        case .activity: "terminal"
        case .diagnostics: "stethoscope"
        }
    }

    var searchScopeLabel: String {
        switch self {
        case .containers: "containers"
        case .images: "images"
        case .volumes: "volumes"
        case .networks: "networks"
        case .kubernetesWorkloads: "workloads"
        case .kubernetesServices: "services"
        case .profiles: "profiles"
        case .activity: "activity"
        default: "results"
        }
    }

    var sidebarSection: String {
        switch self {
        case .overview, .profiles, .activity:
            "Workspace"
        case .containers, .images, .volumes, .networks, .monitor:
            "Runtime"
        case .kubernetesCluster, .kubernetesWorkloads, .kubernetesServices:
            "Kubernetes"
        case .diagnostics:
            "Support"
        }
    }
}

struct WorkspaceDetailRouter: View {
    let route: WorkspaceRoute
    let searchText: String

    var body: some View {
        switch route {
        case .overview:
            OverviewScreen(searchText: searchText)
        case .containers:
            ContainersScreen(searchText: searchText)
        case .images:
            ImagesScreen(searchText: searchText)
        case .volumes:
            VolumesScreen(searchText: searchText)
        case .networks:
            NetworksScreen(searchText: searchText)
        case .monitor:
            MonitorScreen(searchText: searchText)
        case .kubernetesCluster:
            KubernetesClusterScreen(searchText: searchText)
        case .kubernetesWorkloads:
            KubernetesWorkloadsScreen(searchText: searchText)
        case .kubernetesServices:
            KubernetesServicesScreen(searchText: searchText)
        case .profiles:
            ProfilesScreen(searchText: searchText)
        case .activity:
            ActivityScreen(searchText: searchText)
        case .diagnostics:
            DiagnosticsScreen()
        }
    }
}

struct OverviewScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        DetailScreenLayout(
            title: "Overview",
            subtitle: "Current profile, runtime health, and recent operations.",
            symbol: WorkspaceRoute.overview.symbol,
            accessory: {
                HStack(spacing: 10) {
                    Button("Refresh") {
                        Task { await appState.refreshAll() }
                    }
                    .disabled(appState.isRefreshing)

                    Button("Edit Profile") {
                        appState.editSelectedProfile()
                    }
                    .disabled(appState.selectedProfile == nil)
                }
            }
        ) {
            if !appState.hasCollectedDiagnostics || (appState.isRefreshing && appState.profiles.isEmpty) {
                SurfaceStateView(
                    title: "Loading Colima environment",
                    message: "Running startup diagnostics, locating profiles, and capturing the current runtime state.",
                    symbol: "progress.indicator",
                    tone: .info
                )
            } else if !appState.hasColima {
                SurfaceStateView(
                    title: "Colima dependency required",
                    message: "Install or expose the `colima` CLI on PATH, then refresh diagnostics to populate the workspace.",
                    symbol: "externaldrive.badge.xmark",
                    tone: .warning
                ) {
                    Button("Refresh") {
                        Task { await appState.refreshAll() }
                    }
                }
            } else if appState.profiles.isEmpty {
                SurfaceStateView(
                    title: "No profiles configured",
                    message: "Create a profile to define runtime, resources, mounts, networking, and Kubernetes options for this machine.",
                    symbol: "rectangle.stack.badge.plus",
                    tone: .info
                ) {
                    Button("Create Profile") {
                        appState.createProfile()
                    }
                }
            } else {
                if let activeOperation = appState.activeOperation {
                    StatusBanner(
                        title: "Command in progress",
                        message: activeOperation,
                        symbol: "bolt.horizontal.circle",
                        tone: .info
                    )
                } else if let detail = selectedDetail, !detail.errors.isEmpty {
                    StatusBanner(
                        title: "Runtime reported warnings",
                        message: detail.errors.joined(separator: "\n"),
                        symbol: "exclamationmark.triangle",
                        tone: .warning
                    )
                }

                if appState.useEventBus, appState.connectionStatus.anyDegraded {
                    StatusBanner(
                        title: "Live feeds reconnecting",
                        message: connectionStatusSummary,
                        symbol: "arrow.triangle.2.circlepath",
                        tone: .warning
                    )
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    MetricTile(title: "Profile", value: selectedProfile?.name ?? "Unavailable", icon: "rectangle.stack")
                    MetricTile(title: "State", value: selectedProfile?.state.label ?? "Unknown", icon: "power", tone: tone(for: selectedProfile?.state ?? .unknown))
                    MetricTile(title: "Runtime", value: selectedProfile?.runtime?.label ?? "Unknown", icon: "server.rack")
                    MetricTile(title: "Kubernetes", value: selectedProfile?.kubernetes.enabled == true ? "Enabled" : "Disabled", icon: "hexagon")
                    MetricTile(title: "CPU", value: "\(selectedProfile?.resources?.cpu ?? 0) vCPU", icon: "cpu")
                    MetricTile(title: "Memory", value: "\(selectedProfile?.resources?.memoryGiB ?? 0) GiB", icon: "memorychip")
                    MetricTile(title: "Disk", value: selectedProfile?.diskUsage.nonEmpty ?? "\(selectedProfile?.resources?.diskGiB ?? 0) GiB", icon: "internaldrive")
                    MetricTile(title: "Commands", value: "\(appState.commandLog.count)", icon: "terminal")
                }

                SectionCard(
                    title: "Runtime context",
                    subtitle: "Active profile wiring and endpoint details.",
                    symbol: "network"
                ) {
                    KeyValueGrid(rows: [
                        ("Docker context", selectedDetail?.dockerContext ?? selectedProfile?.dockerContext ?? ""),
                        ("Socket", selectedDetail?.socket ?? selectedProfile?.socket ?? ""),
                        ("Address", selectedDetail?.networkAddress ?? selectedProfile?.ipAddress ?? ""),
                        ("Mount driver", selectedProfile?.mountType?.label ?? "Unavailable"),
                        ("VM", selectedProfile?.vmType?.label ?? "Unavailable"),
                        ("Architecture", selectedProfile?.architecture?.label ?? "Unavailable")
                    ])
                }

                SectionCard(
                    title: "Diagnostics snapshot",
                    subtitle: "Toolchain checks and runtime health.",
                    symbol: "stethoscope"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.diagnostics.tools) { tool in
                            ToolRow(tool: tool)
                        }
                        if appState.diagnostics.tools.isEmpty {
                            Text("No diagnostics captured yet.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SectionCard(
                    title: "Recent activity",
                    subtitle: "Latest control plane operations.",
                    symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                ) {
                    let entries = filteredCommands.prefix(4)
                    if entries.isEmpty {
                        Text("No matching command history yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(entries)) { entry in
                                CommandEntryRow(entry: entry)
                            }
                        }
                    }
                }

                SectionCard(
                    title: "Profile logs",
                    subtitle: "Most recent output captured for the selected profile.",
                    symbol: "doc.text"
                ) {
                    TerminalLogView(text: appState.logs, minHeight: 180)
                }
            }
        }
    }

    private var selectedProfile: ColimaProfile? {
        appState.selectedProfile
    }

    private var selectedDetail: ColimaStatusDetail? {
        appState.selectedProfileDetail ?? selectedProfile?.statusDetail
    }

    private var filteredCommands: [CommandLogEntry] {
        appState.commandLog.filter {
            matchesSearch(searchText, values: [$0.command, $0.output, $0.status.label])
        }
    }

    private var connectionStatusSummary: String {
        var parts: [String] = []
        if case .reconnecting = appState.connectionStatus.docker { parts.append("Docker") }
        if case .reconnecting = appState.connectionStatus.kubernetes { parts.append("Kubernetes") }
        if case .reconnecting = appState.connectionStatus.colima { parts.append("Colima") }
        if case .failed = appState.connectionStatus.docker { parts.append("Docker") }
        if case .failed = appState.connectionStatus.kubernetes { parts.append("Kubernetes") }
        if case .failed = appState.connectionStatus.colima { parts.append("Colima") }
        return parts.isEmpty ? "Some live feeds are reconnecting." : "\(parts.joined(separator: ", ")) feed(s) reconnecting."
    }
}

struct ContainersScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String

    @State private var selectedContainerID: DockerContainerResource.ID?
    @State private var filter: ContainerStateFilter = .all
    @State private var selectedTab: ContainerInspectorTab = .overview
    @State private var logsText = ""
    @State private var inspectText = ""
    @State private var logsError: String?
    @State private var inspectError: String?
    @State private var logsIncludeTimestamps = false
    @State private var logsTail = 200
    @State private var logsSearch = ""
    @State private var inspectSearch = ""
    @State private var deleteCandidate: DockerContainerResource?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    private var allContainers: [DockerContainerResource] {
        appState.backendSnapshot?.docker?.containers ?? []
    }

    private var containers: [DockerContainerResource] {
        allContainers.filter {
            filter.includes($0) && matchesSearch(searchText, values: [
                $0.name,
                $0.id,
                $0.image,
                $0.state,
                $0.status,
                $0.ports,
                $0.composeProject ?? "",
                $0.composeService ?? ""
            ] + Array($0.labels.keys) + Array($0.labels.values))
        }.sorted { ($0.name.isEmpty ? $0.id : $0.name).localizedCaseInsensitiveCompare($1.name.isEmpty ? $1.id : $1.name) == .orderedAscending }
    }

    private var containerActionsAreBusy: Bool {
        appState.activeOperation != nil || appState.isRefreshing
    }

    var body: some View {
        DetailScreenLayout(
            title: "Containers",
            subtitle: "Runtime inventory shell with Docker context, endpoint health, and action-ready layout.",
            symbol: WorkspaceRoute.containers.symbol
        ) {
            if !appState.hasColima {
                missingDependencyState
            } else if appState.selectedProfile == nil {
                missingProfileState
            } else if !appState.diagnostics.docker.available {
                SurfaceStateView(
                    title: "Docker endpoint unavailable",
                    message: appState.diagnostics.docker.error.nonEmpty ?? "The selected profile does not currently expose a usable Docker endpoint.",
                    symbol: "shippingbox.circle",
                    tone: .critical
                ) {
                    Button("Refresh") {
                        Task { await appState.refreshAll() }
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    MetricTile(title: "Profile", value: selectedProfile?.name ?? "Unavailable", icon: "rectangle.stack")
                    MetricTile(title: "Context", value: selectedDetail?.dockerContext ?? selectedProfile?.dockerContext ?? "Unavailable", icon: "square.stack.3d.down.forward")
                    MetricTile(title: "Containers", value: "\(allContainers.count)", icon: "shippingbox")
                    MetricTile(title: "Running", value: "\(allContainers.filter { $0.state.lowercased() == "running" }.count)", icon: "play.circle")
                }

                SearchSummaryView(query: searchText, resultCount: containers.count, scopeLabel: WorkspaceRoute.containers.searchScopeLabel)

                SectionCard(
                    title: "Engine access",
                    subtitle: "Current Colima Docker endpoint used for container inventory.",
                    symbol: "server.rack"
                ) {
                    KeyValueGrid(rows: [
                        ("Docker context", selectedDetail?.dockerContext ?? selectedProfile?.dockerContext ?? ""),
                        ("Socket", selectedDetail?.socket ?? selectedProfile?.socket ?? ""),
                        ("Profile state", selectedProfile?.state.label ?? "Unknown"),
                        ("VM address", selectedDetail?.networkAddress ?? selectedProfile?.ipAddress ?? "Unavailable")
                    ])
                }

                SectionCard(title: "Containers", subtitle: "Manage lifecycle, ports, logs, inspect data, terminal commands, and files for the selected Colima context.", symbol: "shippingbox") {
                    containerWorkspace
                }
            }
        }
        .sheet(item: $deleteCandidate) { container in
            ContainerDeleteConfirmationSheet(container: container, isBusy: containerActionsAreBusy) {
                deleteCandidate = nil
            } onConfirm: {
                guard !containerActionsAreBusy else { return }
                deleteCandidate = nil
                Task { await appState.removeContainer(container) }
            }
        }
        .onChange(of: containers.map(\.id)) { _, ids in
            guard let selectedContainerID, !ids.contains(selectedContainerID) else { return }
            self.selectedContainerID = ids.first
        }
        .onChange(of: effectiveSelectedContainerID) { _, _ in
            resetInspectorBuffers()
        }
    }

    private var effectiveSelectedContainerID: DockerContainerResource.ID? {
        selectedContainer?.id
    }

    private var selectedContainer: DockerContainerResource? {
        if let selectedContainerID,
           let container = containers.first(where: { $0.id == selectedContainerID }) ?? allContainers.first(where: { $0.id == selectedContainerID }) {
            return container
        }
        return containers.first
    }

    @ViewBuilder
    private var containerWorkspace: some View {
        if allContainers.isEmpty {
            SurfaceStateView(
                title: "No containers",
                message: "The selected Colima profile has no Docker containers.",
                symbol: "shippingbox",
                tone: .neutral
            )
        } else {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    ContainerToolbar(
                        filter: $filter,
                        stoppedCount: allContainers.filter { ContainerStateFilter.stopped.includes($0) }.count,
                        isBusy: containerActionsAreBusy,
                        onRefresh: { Task { await appState.refreshAll() } },
                        onPruneStopped: { copyContainerText(pruneStoppedCommand) }
                    )

                    let groups = DockerComposeContainerGroup.groups(from: containers)
                    if !groups.isEmpty {
                        ComposeGroupSummary(groups: groups)
                    }

                    if containers.isEmpty {
                        SurfaceStateView(
                            title: "No matching containers",
                            message: "Adjust the search or state filter.",
                            symbol: "shippingbox",
                            tone: .neutral
                        )
                    } else {
                        ContainerControlTable(
                            containers: containers,
                            selectedID: selectedContainer?.id,
                            stats: appState.backendSnapshot?.docker?.stats ?? [],
                            isBusy: containerActionsAreBusy,
                            onSelect: selectContainer,
                            onAction: handleAction
                        )
                    }
                }
                .frame(minWidth: 620)

                ContainerInspector(
                    container: selectedContainer,
                    stats: stats(for: selectedContainer),
                    tab: $selectedTab,
                    logsText: logsText,
                    inspectText: inspectText,
                    logsError: logsError,
                    inspectError: inspectError,
                    logsSearch: $logsSearch,
                    inspectSearch: $inspectSearch,
                    includeTimestamps: $logsIncludeTimestamps,
                    tail: $logsTail,
                    terminalCommand: terminalCommand(for: selectedContainer),
                    isBusy: containerActionsAreBusy,
                    onAction: handleAction,
                    onLoadLogs: loadLogs,
                    onLoadInspect: loadInspect
                )
                .frame(minWidth: 360, maxWidth: 440)
            }
        }
    }

    private var pruneStoppedCommand: String {
        var arguments = ["docker"]
        if let context = (selectedDetail?.dockerContext ?? selectedProfile?.dockerContext)?.nonEmpty {
            arguments += ["--context", context]
        }
        arguments += ["container", "prune"]
        return arguments.map(shellEscaped).joined(separator: " ")
    }

    private func stats(for container: DockerContainerResource?) -> DockerStatsResource? {
        guard let container else { return nil }
        return appState.backendSnapshot?.docker?.stats.first {
            $0.id == container.id || $0.name == container.name || $0.name == container.displayName
        }
    }

    private func terminalCommand(for container: DockerContainerResource?) -> String {
        guard let container, container.availableActions.contains(.terminal) else { return "" }
        return appState.terminalCommand(for: container)
    }

    private func handleAction(_ action: DockerContainerAction, _ container: DockerContainerResource) {
        guard !action.isMutating || !containerActionsAreBusy else { return }

        switch action {
        case .start:
            Task { await appState.startContainer(container) }
        case .stop:
            Task { await appState.stopContainer(container) }
        case .restart:
            Task { await appState.restartContainer(container) }
        case .pause:
            Task { await appState.pauseContainer(container) }
        case .resume:
            Task { await appState.resumeContainer(container) }
        case .kill:
            Task { await appState.killContainer(container) }
        case .delete:
            deleteCandidate = container
        case .logs:
            selectContainer(container)
            selectedTab = .logs
            loadLogs()
        case .inspect:
            selectContainer(container)
            selectedTab = .inspect
            loadInspect()
        case .terminal:
            guard container.availableActions.contains(.terminal) else { return }
            selectContainer(container)
            selectedTab = .terminal
            copyContainerText(appState.terminalCommand(for: container))
        case .openPort:
            if let url = container.portBindings.first?.browserURL {
                NSWorkspace.shared.open(url)
            }
        case .copyID:
            copyContainerText(container.id)
        case .copyImage:
            copyContainerText(container.image)
        case .copyPorts:
            copyContainerText(container.ports)
        }
    }

    private func selectContainer(_ container: DockerContainerResource) {
        selectedContainerID = container.id
    }

    private func resetInspectorBuffers() {
        logsText = ""
        inspectText = ""
        logsError = nil
        inspectError = nil
        logsSearch = ""
        inspectSearch = ""
    }

    private func loadLogs() {
        guard let container = selectedContainer else { return }
        let requestedContainer = container
        let requestedID = requestedContainer.id
        logsError = nil
        Task {
            do {
                let output = try await appState.containerLogs(requestedContainer, timestamps: logsIncludeTimestamps, tail: logsTail)
                guard selectedContainer?.id == requestedID else { return }
                logsText = output
            } catch {
                guard selectedContainer?.id == requestedID else { return }
                logsError = error.localizedDescription
            }
        }
    }

    private func loadInspect() {
        guard let container = selectedContainer else { return }
        let requestedContainer = container
        let requestedID = requestedContainer.id
        inspectError = nil
        Task {
            do {
                let output = prettyJSON(try await appState.inspectContainer(requestedContainer))
                guard selectedContainer?.id == requestedID else { return }
                inspectText = output
            } catch {
                guard selectedContainer?.id == requestedID else { return }
                inspectError = error.localizedDescription
            }
        }
    }

    private var selectedProfile: ColimaProfile? { appState.selectedProfile }
    private var selectedDetail: ColimaStatusDetail? { appState.selectedProfileDetail ?? selectedProfile?.statusDetail }
    private var missingDependencyState: some View {
        SurfaceStateView(
            title: "Runtime not available",
            message: "Container management depends on a reachable Colima and Docker toolchain.",
            symbol: "shippingbox.circle",
            tone: .warning
        )
    }
    private var missingProfileState: some View {
        SurfaceStateView(
            title: "Choose a profile",
            message: "Select or create a Colima profile before inspecting containers.",
            symbol: "rectangle.stack.badge.plus",
            tone: .info
        ) {
            Button("Create Profile") {
                appState.createProfile()
            }
        }
    }
}

private enum ContainerStateFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case running = "Running"
    case stopped = "Stopped"
    case paused = "Paused"
    case error = "Error"

    var id: String { rawValue }

    func includes(_ container: DockerContainerResource) -> Bool {
        switch self {
        case .all:
            true
        case .running:
            container.normalizedState == "running"
        case .stopped:
            ["exited", "created", "stopped"].contains(container.normalizedState)
        case .paused:
            container.normalizedState == "paused"
        case .error:
            container.normalizedState == "dead" || container.health == .error
        }
    }
}

private enum ContainerInspectorTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case logs = "Logs"
    case inspect = "Inspect"
    case stats = "Stats"
    case terminal = "Terminal"
    case files = "Files"
    case ports = "Ports"

    var id: String { rawValue }
}

private struct ContainerToolbar: View {
    @Binding var filter: ContainerStateFilter
    let stoppedCount: Int
    let isBusy: Bool
    let onRefresh: () -> Void
    let onPruneStopped: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Picker("Container state", selection: $filter) {
                ForEach(ContainerStateFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)

            Spacer()

            Button {
                onRefresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isBusy)

            Button {
                onPruneStopped()
            } label: {
                Label("Prune \(stoppedCount)", systemImage: "trash")
            }
            .disabled(isBusy || stoppedCount == 0)
            .help("Copies `docker container prune`; execute destructive pruning from the terminal.")
        }
    }
}

private struct ComposeGroupSummary: View {
    let groups: [DockerComposeContainerGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compose projects")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(groups) { group in
                    Text("\(group.projectName) · \(group.runningCount)/\(group.containers.count) running")
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .underPageBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

private struct ContainerControlTable: View {
    let containers: [DockerContainerResource]
    let selectedID: DockerContainerResource.ID?
    let stats: [DockerStatsResource]
    let isBusy: Bool
    let onSelect: (DockerContainerResource) -> Void
    let onAction: (DockerContainerAction, DockerContainerResource) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ContainerTableHeader()
            ForEach(containers) { container in
                ContainerControlRow(
                    container: container,
                    stats: stat(for: container),
                    isSelected: container.id == selectedID,
                    isBusy: isBusy,
                    onSelect: { onSelect(container) },
                    onAction: { onAction($0, container) }
                )
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("containers.table")
    }

    private func stat(for container: DockerContainerResource) -> DockerStatsResource? {
        stats.first { $0.id == container.id || $0.name == container.name || $0.name == container.displayName }
    }
}

private struct ContainerTableHeader: View {
    private let columns = ["Name", "Image", "Status", "Ports", "CPU", "Memory", "Uptime", "Actions"]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns, id: \.self) { column in
                Text(column)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: column == "Actions" ? 120 : .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private struct ContainerControlRow: View {
    let container: DockerContainerResource
    let stats: DockerStatsResource?
    let isSelected: Bool
    let isBusy: Bool
    let onSelect: () -> Void
    let onAction: (DockerContainerAction) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(container.displayName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let project = container.composeProject {
                    Text([project, container.composeService].compactMap { $0 }.joined(separator: " / "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            tableText(container.image)
            tableText(container.status.isEmpty ? container.state : container.status, color: tone.foregroundColor)
            tableText(container.ports.isEmpty ? "No exposed ports" : container.ports)
            tableText(stats?.cpuPercent.nonEmpty ?? "-")
            tableText(stats?.memoryUsage.nonEmpty ?? "-")
            tableText(container.runningFor.nonEmpty ?? container.createdAt.nonEmpty ?? "-")

            ContainerRowActions(container: container, isBusy: isBusy, onAction: onAction)
                .frame(maxWidth: 120, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 12)
        }
        .contextMenu {
            ContainerActionsMenu(container: container, isBusy: isBusy, onAction: onAction)
        }
        .accessibilityIdentifier("container.row.\(container.id)")
    }

    private func tableText(_ value: String, color: Color = .secondary) -> some View {
        Text(value)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tone: WorkspaceTone {
        switch container.health {
        case .healthy: .success
        case .warning: .warning
        case .error: .critical
        case .unknown: .neutral
        }
    }
}

private struct ContainerRowActions: View {
    let container: DockerContainerResource
    let isBusy: Bool
    let onAction: (DockerContainerAction) -> Void

    var body: some View {
        HStack(spacing: 4) {
            if container.availableActions.contains(.start) {
                iconButton("Start", "play.fill", .start)
            }
            if container.availableActions.contains(.stop) {
                iconButton("Stop", "stop.fill", .stop)
            }
            if container.availableActions.contains(.restart) {
                iconButton("Restart", "arrow.clockwise", .restart)
            }
            if container.availableActions.contains(.openPort) {
                iconButton("Open port", "safari", .openPort)
            }
            Menu {
                ContainerActionsMenu(container: container, isBusy: isBusy, onAction: onAction)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .disabled(isBusy)
            .accessibilityIdentifier("container.action.more")
        }
    }

    private func iconButton(_ label: String, _ symbol: String, _ action: DockerContainerAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Image(systemName: symbol)
        }
        .buttonStyle(.borderless)
        .disabled(isBusy)
        .help(label)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}

private struct ContainerActionsMenu: View {
    let container: DockerContainerResource
    let isBusy: Bool
    let onAction: (DockerContainerAction) -> Void

    var body: some View {
        ForEach(primaryActions, id: \.self) { action in
            Button(action.title, systemImage: action.symbol) {
                onAction(action)
            }
            .disabled(isBusy)
        }
        Divider()
        Button("Logs", systemImage: "doc.text.magnifyingglass") { onAction(.logs) }
        Button("Inspect JSON", systemImage: "curlybraces") { onAction(.inspect) }
        if container.availableActions.contains(.terminal) {
            Button("Copy terminal command", systemImage: "terminal") { onAction(.terminal) }
        }
        if container.availableActions.contains(.openPort) {
            Button("Open port in browser", systemImage: "safari") { onAction(.openPort) }
        }
        Divider()
        Button("Copy ID", systemImage: "doc.on.doc") { onAction(.copyID) }
        Button("Copy image", systemImage: "doc.on.doc") { onAction(.copyImage) }
        if container.availableActions.contains(.copyPorts) {
            Button("Copy ports", systemImage: "doc.on.doc") { onAction(.copyPorts) }
        }
        if container.availableActions.contains(.delete) {
            Divider()
            Button("Delete...", systemImage: "trash", role: .destructive) { onAction(.delete) }
                .disabled(isBusy)
        }
    }

    private var primaryActions: [DockerContainerAction] {
        [.start, .stop, .restart, .pause, .resume, .kill].filter { container.availableActions.contains($0) }
    }
}

private extension DockerContainerAction {
    var title: String {
        switch self {
        case .start: "Start"
        case .stop: "Stop"
        case .restart: "Restart"
        case .pause: "Pause"
        case .resume: "Resume"
        case .kill: "Kill"
        case .delete: "Delete"
        case .logs: "Logs"
        case .inspect: "Inspect"
        case .terminal: "Terminal"
        case .openPort: "Open Port"
        case .copyID: "Copy ID"
        case .copyImage: "Copy Image"
        case .copyPorts: "Copy Ports"
        }
    }

    var symbol: String {
        switch self {
        case .start: "play.fill"
        case .stop: "stop.fill"
        case .restart: "arrow.clockwise"
        case .pause: "pause.fill"
        case .resume: "playpause"
        case .kill: "xmark.octagon"
        case .delete: "trash"
        case .logs: "doc.text"
        case .inspect: "curlybraces"
        case .terminal: "terminal"
        case .openPort: "safari"
        case .copyID, .copyImage, .copyPorts: "doc.on.doc"
        }
    }

    var accessibilityIdentifier: String {
        "container.action.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
    }

    var isMutating: Bool {
        switch self {
        case .start, .stop, .restart, .pause, .resume, .kill, .delete:
            true
        case .logs, .inspect, .terminal, .openPort, .copyID, .copyImage, .copyPorts:
            false
        }
    }
}

private struct ContainerInspector: View {
    let container: DockerContainerResource?
    let stats: DockerStatsResource?
    @Binding var tab: ContainerInspectorTab
    let logsText: String
    let inspectText: String
    let logsError: String?
    let inspectError: String?
    @Binding var logsSearch: String
    @Binding var inspectSearch: String
    @Binding var includeTimestamps: Bool
    @Binding var tail: Int
    let terminalCommand: String
    let isBusy: Bool
    let onAction: (DockerContainerAction, DockerContainerResource) -> Void
    let onLoadLogs: () -> Void
    let onLoadInspect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let container {
                inspectorHeader(container)

                Picker("Container detail", selection: $tab) {
                    ForEach(ContainerInspectorTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("container.inspector.tabs")

                tabContent(container)
            } else {
                SurfaceStateView(
                    title: "Select a container",
                    message: "Choose a container to inspect logs, ports, stats, terminal commands, files, and raw Docker metadata.",
                    symbol: "sidebar.right",
                    tone: .info
                )
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("container.inspector")
    }

    private func inspectorHeader(_ container: DockerContainerResource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(container.displayName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(container.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text(container.state.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(container.health == .healthy ? .green : container.health == .error ? .red : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .underPageBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            ContainerRowActions(container: container, isBusy: isBusy) { onAction($0, container) }
        }
    }

    @ViewBuilder
    private func tabContent(_ container: DockerContainerResource) -> some View {
        switch tab {
        case .overview:
            KeyValueGrid(rows: [
                ("Image", container.image),
                ("Command", container.command),
                ("Status", container.status.isEmpty ? container.state : container.status),
                ("Created", container.createdAt),
                ("Running for", container.runningFor),
                ("Size", container.size),
                ("Compose", [container.composeProject, container.composeService].compactMap { $0 }.joined(separator: " / ")),
                ("Labels", container.labels.isEmpty ? "No labels" : container.labels.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n"))
            ])
        case .logs:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Timestamps", isOn: $includeTimestamps)
                    Stepper("Tail \(tail)", value: $tail, in: 50...2000, step: 50)
                    Button("Load") { onLoadLogs() }
                    Button("Copy") { copyContainerText(logsText) }.disabled(logsText.isEmpty)
                }
                TextField("Search logs", text: $logsSearch)
                if let logsError {
                    StatusBanner(title: "Unable to load logs", message: logsError, symbol: "exclamationmark.triangle", tone: .warning)
                }
                TerminalLogView(text: filtered(logsText, query: logsSearch), minHeight: 260)
            }
        case .inspect:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Search inspect JSON", text: $inspectSearch)
                    Button("Load") { onLoadInspect() }
                    Button("Copy") { copyContainerText(inspectText) }.disabled(inspectText.isEmpty)
                }
                if let inspectError {
                    StatusBanner(title: "Unable to inspect container", message: inspectError, symbol: "exclamationmark.triangle", tone: .warning)
                }
                TerminalLogView(text: inspectText.isEmpty ? "Load inspect JSON to view low-level Docker metadata." : filtered(inspectText, query: inspectSearch), minHeight: 260)
            }
        case .stats:
            KeyValueGrid(rows: [
                ("CPU", stats?.cpuPercent ?? "Unavailable"),
                ("Memory", stats?.memoryUsage ?? "Unavailable"),
                ("Memory %", stats?.memoryPercent ?? "Unavailable"),
                ("Network I/O", stats?.networkIO ?? "Unavailable"),
                ("Block I/O", stats?.blockIO ?? "Unavailable"),
                ("PIDs", stats?.pids ?? "Unavailable")
            ])
        case .terminal:
            VStack(alignment: .leading, spacing: 10) {
                Text("Interactive terminal command")
                    .font(.headline)
                TerminalLogView(text: terminalCommand.isEmpty ? "No terminal command available." : terminalCommand, minHeight: 90)
                HStack {
                    Button("Copy /bin/sh") { copyContainerText(terminalCommand) }
                    Button("Copy /bin/bash") { copyContainerText(terminalCommand.replacingOccurrences(of: "/bin/sh", with: "/bin/bash")) }
                }
                .disabled(terminalCommand.isEmpty)
            }
        case .files:
            let mounts = containerMounts(from: inspectText)
            VStack(alignment: .leading, spacing: 10) {
                Text("Volumes and bind-mount clues")
                    .font(.headline)
                if inspectText.isEmpty {
                    Text("Load inspect JSON to show mounts for this container.")
                        .foregroundStyle(.secondary)
                    Button("Load Inspect") { onLoadInspect() }
                } else if mounts.isEmpty {
                    Text("No mounts were reported for this container.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mounts.prefix(8)) { mount in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mount.title)
                                    .fontWeight(.medium)
                                Text(mount.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            if let url = mount.fileURL {
                                Button {
                                    NSWorkspace.shared.open(url)
                                } label: {
                                    Image(systemName: "folder")
                                }
                                .buttonStyle(.borderless)
                                .help("Open mount source in Finder")
                            }
                        }
                    }
                }
            }
        case .ports:
            VStack(alignment: .leading, spacing: 10) {
                if container.portBindings.isEmpty {
                    Text(container.ports.isEmpty ? "No published ports." : container.ports)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(container.portBindings) { binding in
                        HStack {
                            Text("\(binding.hostIP):\(binding.hostPort) -> \(binding.containerPort)/\(binding.proto)")
                                .lineLimit(1)
                            Spacer()
                            if let url = binding.browserURL {
                                Button("Open") { NSWorkspace.shared.open(url) }
                            }
                            Button("Copy") { copyContainerText("\(binding.hostIP):\(binding.hostPort)") }
                        }
                    }
                }
            }
        }
    }

    private func filtered(_ text: String, query: String) -> String {
        guard !query.isEmpty else { return text }
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .joined(separator: "\n")
    }
}

private struct ContainerMount: Identifiable, Hashable {
    var type: String
    var name: String
    var source: String
    var destination: String

    var id: String { [type, name, source, destination].joined(separator: "|") }

    var title: String {
        name.nonEmpty ?? source.nonEmpty ?? destination.nonEmpty ?? "Mount"
    }

    var subtitle: String {
        let target = destination.nonEmpty ?? "unknown target"
        if let source = source.nonEmpty {
            return "\(type.nonEmpty ?? "mount"): \(source) -> \(target)"
        }
        return "\(type.nonEmpty ?? "mount"): \(target)"
    }

    var fileURL: URL? {
        guard type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "bind",
              let source = source.nonEmpty,
              source.hasPrefix("/") else {
            return nil
        }
        return URL(fileURLWithPath: source)
    }
}

private func containerMounts(from inspectText: String) -> [ContainerMount] {
    guard let data = inspectText.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) else {
        return []
    }

    let object: [String: Any]?
    if let array = root as? [[String: Any]] {
        object = array.first
    } else {
        object = root as? [String: Any]
    }

    guard let mounts = object?["Mounts"] as? [[String: Any]] else { return [] }
    return mounts.compactMap { mount in
        let value = ContainerMount(
            type: mount.string("Type"),
            name: mount.string("Name"),
            source: mount.string("Source"),
            destination: mount.string("Destination", "Target")
        )
        return value.source.isEmpty && value.destination.isEmpty && value.name.isEmpty ? nil : value
    }
}

private struct ContainerDeleteConfirmationSheet: View {
    let container: DockerContainerResource
    let isBusy: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete container")
                .font(.title3.weight(.semibold))
            Text("Type \(container.displayName) to delete this container. This removes the stopped container record and cannot be undone from ColimaStack.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField(container.displayName, text: $confirmation)
                .accessibilityIdentifier("container.delete.confirmationText")
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .accessibilityIdentifier("container.delete.cancel")
                Button("Delete", role: .destructive) { onConfirm() }
                    .disabled(isBusy || confirmation != container.displayName)
                    .accessibilityIdentifier("container.delete.confirm")
            }
        }
        .padding(22)
        .frame(width: 420)
    }
}

private func copyContainerText(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

private func shellEscaped(_ value: String) -> String {
    let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-")
    if value.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) {
        return value
    }
    return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

private func prettyJSON(_ value: String) -> String {
    guard let data = value.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
          let string = String(data: formatted, encoding: .utf8) else {
        return value
    }
    return string
}

struct ImagesScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String
    private var images: [DockerImageResource] {
        (appState.backendSnapshot?.docker?.images ?? []).filter {
            matchesSearch(searchText, values: [$0.displayName, $0.id, $0.digest, $0.size])
        }.sorted { ($0.displayName.isEmpty ? $0.id : $0.displayName).localizedCaseInsensitiveCompare($1.displayName.isEmpty ? $1.id : $1.displayName) == .orderedAscending }
    }

    var body: some View {
        DetailScreenLayout(
            title: "Images",
            subtitle: "Local images, tags, digests, and sizes for the selected Colima runtime.",
            symbol: WorkspaceRoute.images.symbol
        ) {
            if !appState.hasColima {
                missingDependencyState
            } else if appState.selectedProfile == nil {
                missingProfileState
            } else if !appState.diagnostics.docker.available {
                SurfaceStateView(
                    title: "Docker image store unavailable",
                    message: appState.diagnostics.docker.error.nonEmpty ?? "Connect a Docker-capable profile to inspect image layers and tags.",
                    symbol: "square.stack.3d.up.slash",
                    tone: .critical
                )
            } else {
                SearchSummaryView(query: searchText, resultCount: images.count, scopeLabel: WorkspaceRoute.images.searchScopeLabel)

                SectionCard(
                    title: "Image store context",
                    subtitle: "Current selection is wired to the following runtime targets.",
                    symbol: "tray.full"
                ) {
                    KeyValueGrid(rows: [
                        ("Profile", appState.selectedProfile?.name ?? ""),
                        ("Runtime", appState.selectedProfile?.runtime?.label ?? ""),
                        ("Docker version", appState.diagnostics.docker.version),
                        ("Context", appState.selectedProfileDetail?.dockerContext ?? appState.selectedProfile?.dockerContext ?? "")
                    ])
                }

                SectionCard(title: "Images", subtitle: "Docker image records from the selected Colima context.", symbol: "square.stack.3d.up") {
                    if images.isEmpty {
                        SurfaceStateView(
                            title: searchText.isEmpty ? "No images" : "No matching images",
                            message: searchText.isEmpty ? "Pull or build images inside this Colima profile to populate the catalog." : "Adjust the search or clear the filter.",
                            symbol: "square.stack.3d.up",
                            tone: .neutral
                        )
                    } else {
                        RecordList(columns: ["Repository", "Tag", "Size", "Created"]) {
                            ForEach(images) { image in
                                RecordRow(
                                    leading: image.repository.isEmpty ? image.id : image.repository,
                                    secondary: image.id,
                                    tertiary: image.size,
                                    trailing: image.createdSince.isEmpty ? image.createdAt : image.createdSince
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var missingDependencyState: some View {
        SurfaceStateView(
            title: "Image tooling unavailable",
            message: "Install Colima and expose Docker to make the image catalog available.",
            symbol: "square.stack.3d.up.slash",
            tone: .warning
        )
    }

    private var missingProfileState: some View {
        SurfaceStateView(
            title: "No profile selected",
            message: "Select a profile before browsing image metadata.",
            symbol: "rectangle.stack",
            tone: .info
        )
    }
}

struct VolumesScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String

    private var filteredMounts: [ColimaMount] {
        (appState.selectedProfile?.mounts ?? []).filter {
            matchesSearch(searchText, values: [$0.location, $0.mountPoint ?? "", $0.cliValue])
        }
    }
    private var volumes: [DockerVolumeResource] {
        (appState.backendSnapshot?.docker?.volumes ?? []).filter {
            matchesSearch(searchText, values: [$0.name, $0.driver, $0.scope, $0.mountpoint])
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        DetailScreenLayout(
            title: "Volumes",
            subtitle: "Host profile mounts and Docker-managed runtime volumes.",
            symbol: WorkspaceRoute.volumes.symbol
        ) {
            if !appState.hasColima {
                missingDependencyState
            } else if appState.selectedProfile == nil {
                missingProfileState
            } else {
                SearchSummaryView(query: searchText, resultCount: filteredMounts.count + volumes.count, scopeLabel: WorkspaceRoute.volumes.searchScopeLabel)

                SectionCard(
                    title: "Configured mounts",
                    subtitle: "Profile-defined host paths currently available from AppState.",
                    symbol: "folder"
                ) {
                    if filteredMounts.isEmpty {
                        Text(searchText.isEmpty ? "No mounts configured for this profile." : "No mounts match the current search.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filteredMounts) { mount in
                                HStack(alignment: .top, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mount.mountPoint.nonEmpty ?? mount.location)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        Text(mount.location)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(mount.writable == false ? "Read Only" : "Writable")
                                        .foregroundStyle(mount.writable == false ? .orange : .secondary)
                                }
                                .padding(.vertical, 10)
                                if mount.id != filteredMounts.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                SectionCard(title: "Runtime volumes", subtitle: "Docker volumes from the selected Colima context.", symbol: "externaldrive") {
                    if volumes.isEmpty {
                        Text(searchText.isEmpty ? "No runtime volumes found." : "No runtime volumes match the current search.")
                            .foregroundStyle(.secondary)
                    } else {
                        RecordList(columns: ["Name", "Driver", "Scope", "Mountpoint"]) {
                            ForEach(volumes) { volume in
                                RecordRow(leading: volume.name, secondary: volume.driver, tertiary: volume.scope, trailing: volume.mountpoint)
                            }
                        }
                    }
                }
            }
        }
    }

    private var missingDependencyState: some View {
        SurfaceStateView(
            title: "Volume surface unavailable",
            message: "Host mount and runtime volume inspection requires a reachable Colima setup.",
            symbol: "externaldrive.badge.xmark",
            tone: .warning
        )
    }

    private var missingProfileState: some View {
        SurfaceStateView(
            title: "Select a profile",
            message: "Mount configuration is tied to an individual Colima profile.",
            symbol: "rectangle.stack",
            tone: .info
        )
    }
}

struct NetworksScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String
    private var dockerNetworks: [DockerNetworkResource] {
        (appState.backendSnapshot?.docker?.networks ?? []).filter {
            matchesSearch(searchText, values: [$0.name, $0.id, $0.driver, $0.scope])
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var networkRows: [(String, String, String, String)] {
        guard let profile = appState.selectedProfile else { return [] }
        let detail = appState.selectedProfileDetail ?? profile.statusDetail
        let vmName = "vm-\(profile.name)"
        let vmState = profile.state.label
        let vmEndpoint = detail.networkAddress.nonEmpty ?? "Not exposed"
        let vmContext = detail.socket.nonEmpty ?? profile.socket.nonEmpty ?? "Unavailable"
        let vmRow: (String, String, String, String) = (vmName, vmState, vmEndpoint, vmContext)

        let dockerName = "docker-\(profile.name)"
        let dockerState = appState.diagnostics.docker.available ? "Ready" : "Unavailable"
        let dockerEndpoint = detail.dockerContext.nonEmpty ?? profile.dockerContext.nonEmpty ?? "Unavailable"
        let dockerContext = appState.diagnostics.docker.version.nonEmpty ?? "Version unavailable"
        let dockerRow: (String, String, String, String) = (dockerName, dockerState, dockerEndpoint, dockerContext)

        let rows: [(String, String, String, String)] = [
            vmRow,
            dockerRow
        ]
        return rows.filter { row in
            matchesSearch(searchText, values: [row.0, row.1, row.2, row.3])
        }
    }

    var body: some View {
        DetailScreenLayout(
            title: "Networks",
            subtitle: "Profile networking, endpoint paths, and runtime access surfaces.",
            symbol: WorkspaceRoute.networks.symbol
        ) {
            if !appState.hasColima {
                missingDependencyState
            } else if appState.selectedProfile == nil {
                missingProfileState
            } else {
                SearchSummaryView(query: searchText, resultCount: networkRows.count + dockerNetworks.count, scopeLabel: WorkspaceRoute.networks.searchScopeLabel)

                if networkRows.isEmpty {
                    SurfaceStateView(
                        title: "No network records matched",
                        message: "Adjust the search or refresh the selected profile to repopulate runtime endpoints.",
                        symbol: "network.slash",
                        tone: .warning
                    )
                } else {
                    RecordList(columns: ["Name", "State", "Endpoint", "Context"]) {
                        ForEach(Array(networkRows.enumerated()), id: \.offset) { index, row in
                            RecordRow(leading: row.0, secondary: row.1, tertiary: row.2, trailing: row.3, tone: row.1 == "Unavailable" ? .critical : .neutral)
                                .overlay(alignment: .bottom) {
                                    if index == networkRows.count - 1 {
                                        EmptyView()
                                    }
                                }
                        }
                    }
                }

                SectionCard(
                    title: "Connectivity details",
                    subtitle: "Useful network values already exposed by the current runtime API.",
                    symbol: "antenna.radiowaves.left.and.right"
                ) {
                    KeyValueGrid(rows: [
                        ("Address", appState.selectedProfileDetail?.networkAddress ?? appState.selectedProfile?.ipAddress ?? ""),
                        ("Docker context", appState.selectedProfileDetail?.dockerContext ?? appState.selectedProfile?.dockerContext ?? ""),
                        ("Socket", appState.selectedProfileDetail?.socket ?? appState.selectedProfile?.socket ?? ""),
                        ("Kubernetes context", appState.selectedProfile?.kubernetes.context ?? "")
                    ])
                }

                SectionCard(title: "Runtime networks", subtitle: "Docker networks in the selected Colima context.", symbol: "network") {
                    if dockerNetworks.isEmpty {
                        Text(searchText.isEmpty ? "No Docker networks found." : "No Docker networks match the current search.")
                            .foregroundStyle(.secondary)
                    } else {
                        RecordList(columns: ["Name", "Driver", "Scope", "Flags"]) {
                            ForEach(dockerNetworks) { network in
                                let flags = [network.internalOnly ? "Internal" : "", network.ipv6Enabled ? "IPv6" : ""].filter { !$0.isEmpty }.joined(separator: ", ")
                                RecordRow(leading: network.name, secondary: network.id, tertiary: network.driver, trailing: flags.isEmpty ? network.scope : flags)
                            }
                        }
                    }
                }
            }
        }
    }

    private var missingDependencyState: some View {
        SurfaceStateView(
            title: "Networking checks unavailable",
            message: "Colima diagnostics must be available before showing endpoint and context data.",
            symbol: "network.slash",
            tone: .warning
        )
    }

    private var missingProfileState: some View {
        SurfaceStateView(
            title: "Select a profile",
            message: "Network state is scoped to a specific runtime profile.",
            symbol: "rectangle.stack",
            tone: .info
        )
    }
}

struct MonitorScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String

    var body: some View {
        DetailScreenLayout(
            title: "Monitor",
            subtitle: "Realtime CPU, memory, disk, and network usage for the active profile.",
            symbol: WorkspaceRoute.monitor.symbol
        ) {
            if !appState.hasColima {
                missingDependencyState
            } else if appState.selectedProfile == nil {
                missingProfileState
            } else {
                let resources = appState.selectedProfile?.resources ?? .standard
                let runningCount = appState.profiles.filter { $0.state == .running }.count
                let failureCount = appState.commandLog.filter { $0.status.isFailure }.count
                let usage = currentUsage
                let previousUsage = previousUsage
                let networkRate = networkRateText(current: usage, previous: previousUsage)

                if let activeOperation = appState.activeOperation {
                    StatusBanner(
                        title: "Collecting runtime feedback",
                        message: activeOperation,
                        symbol: "waveform.badge.magnifyingglass",
                        tone: .info
                    )
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    MetricTile(title: "CPU used", value: usage.map { formatPercent($0.cpuPercent) } ?? "Unavailable", icon: "cpu")
                    MetricTile(title: "Memory used", value: usage.map { formatBytes($0.memoryUsedBytes) } ?? "Unavailable", icon: "memorychip")
                    MetricTile(title: "Disk used", value: usage.map { formatBytes($0.diskUsedBytes) } ?? "Unavailable", icon: "internaldrive")
                    MetricTile(title: "Network", value: networkRate ?? "Unavailable", icon: "arrow.up.arrow.down")
                }

                SectionCard(
                    title: "Current usage",
                    subtitle: usage.map { "Last sample: \(relativeTime($0.collectedAt)). Docker data disk usage comes from `docker system df`." } ?? "Refresh while the profile is running to collect live usage.",
                    symbol: "gauge.with.dots.needle.50percent"
                ) {
                    if let usage {
                        VStack(spacing: 14) {
                            UsageBar(label: "CPU", value: "\(formatPercent(usage.cpuPercent)) of \(resources.cpu) vCPU", progress: usage.cpuPercent / max(Double(resources.cpu * 100), 1), tint: .blue)
                            UsageBar(label: "Memory", value: "\(formatBytes(usage.memoryUsedBytes)) / \(resources.memoryGiB) GiB", progress: usage.memoryProgress, tint: .green)
                            UsageBar(label: "Disk", value: "\(formatBytes(usage.diskUsedBytes)) / \(resources.diskGiB) GiB", progress: usage.diskProgress, tint: .orange)
                            UsageBar(label: "Block I/O", value: "\(formatBytes(usage.blockReadBytes)) read / \(formatBytes(usage.blockWriteBytes)) write", progress: normalizedBlockIOProgress(usage, history: usageHistory), tint: .indigo)
                        }
                    } else {
                        SurfaceStateView(
                            title: "Live usage unavailable",
                            message: "No runtime sample has been collected for the selected running profile.",
                            symbol: "waveform.path.badge.minus",
                            tone: .info
                        )
                    }
                }

                SectionCard(
                    title: "Usage graphs",
                    subtitle: "History is built from the automatic refresh loop and manual refreshes.",
                    symbol: "chart.xyaxis.line"
                ) {
                    let history = usageHistory
                    if history.isEmpty {
                        Text("No usage history yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                            RuntimeMetricChart(
                                title: "CPU",
                                unit: "%",
                                tint: .blue,
                                points: history.map { RuntimeMetricPoint(date: $0.collectedAt, value: $0.cpuPercent) }
                            )
                            RuntimeMetricChart(
                                title: "Memory",
                                unit: "GiB",
                                tint: .green,
                                points: history.map { RuntimeMetricPoint(date: $0.collectedAt, value: $0.memoryUsedBytes / 1_073_741_824) }
                            )
                            RuntimeMetricChart(
                                title: "Disk",
                                unit: "GiB",
                                tint: .orange,
                                points: history.map { RuntimeMetricPoint(date: $0.collectedAt, value: $0.diskUsedBytes / 1_073_741_824) }
                            )
                            RuntimeTrafficChart(points: trafficRatePoints(from: history))
                        }
                    }
                }

                SectionCard(
                    title: "Capacity allocations",
                    subtitle: "Configured ceilings for the selected profile.",
                    symbol: "slider.horizontal.3"
                ) {
                    VStack(spacing: 14) {
                        UsageBar(label: "CPU", value: "\(resources.cpu) vCPU", progress: normalized(resources.cpu, against: 12), tint: .blue)
                        UsageBar(label: "Memory", value: "\(resources.memoryGiB) GiB", progress: normalized(resources.memoryGiB, against: 32), tint: .green)
                        UsageBar(label: "Disk", value: "\(resources.diskGiB) GiB", progress: normalized(resources.diskGiB, against: 200), tint: .orange)
                    }
                }

                SectionCard(
                    title: "Health signals",
                    subtitle: "Signals that matter for a developer-facing runtime dashboard.",
                    symbol: "heart.text.square"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        StatusBanner(
                            title: "Runtime",
                            message: "\(usage?.runningContainerCount ?? 0) running container(s). \(runningCount) Colima profile(s) running. \(failureCount) command failure(s).",
                            symbol: "play.circle",
                            tone: failureCount == 0 ? .success : .warning
                        )
                        StatusBanner(
                            title: "Docker",
                            message: appState.diagnostics.docker.available ? "Docker context \(appState.diagnostics.docker.context.nonEmpty ?? "colima") is available." : appState.diagnostics.docker.error.nonEmpty ?? "Docker is not available.",
                            symbol: "shippingbox",
                            tone: appState.diagnostics.docker.available ? .success : .critical
                        )
                        StatusBanner(
                            title: "Kubernetes",
                            message: appState.selectedProfile?.kubernetes.enabled == true ? "Context \(appState.selectedProfile?.kubernetes.context.nonEmpty ?? "colima") is enabled." : "Kubernetes is disabled for the selected profile.",
                            symbol: "hexagon",
                            tone: appState.selectedProfile?.kubernetes.enabled == true ? .info : .neutral
                        )
                    }
                }
            }
        }
    }

    private var missingDependencyState: some View {
        SurfaceStateView(
            title: "Monitor unavailable",
            message: "Runtime monitoring depends on successful Colima diagnostics.",
            symbol: "waveform.path.badge.minus",
            tone: .warning
        )
    }

    private var missingProfileState: some View {
        SurfaceStateView(
            title: "No profile selected",
            message: "Choose a profile to inspect its allocations and health signals.",
            symbol: "rectangle.stack",
            tone: .info
        )
    }

    private var usageHistory: [RuntimeUsageSample] {
        guard let profileID = appState.selectedProfile?.id else { return [] }
        return appState.monitorHistory
            .filter { $0.profileID == profileID }
            .sorted { $0.collectedAt < $1.collectedAt }
    }

    private var currentUsage: RuntimeUsageSample? {
        guard appState.selectedProfile?.state == .running else { return nil }
        return usageHistory.last ?? appState.backendSnapshot?.runtimeUsageSample()
    }

    private var previousUsage: RuntimeUsageSample? {
        let history = usageHistory
        guard history.count >= 2 else { return nil }
        return history[history.count - 2]
    }
}

private struct RuntimeMetricPoint: Identifiable {
    let id = UUID()
    var date: Date
    var value: Double
}

private struct RuntimeTrafficPoint: Identifiable {
    let id = UUID()
    var date: Date
    var direction: String
    var value: Double
}

private struct RuntimeMetricChart: View {
    let title: String
    let unit: String
    let tint: Color
    let points: [RuntimeMetricPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Chart(points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value(unit, point.value)
                )
                .foregroundStyle(tint)
                .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value(unit, point.value)
                )
                .foregroundStyle(tint.opacity(0.14))
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .frame(height: 150)
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct RuntimeTrafficChart: View {
    let points: [RuntimeTrafficPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Network")
                .font(.subheadline.weight(.semibold))
            Chart(points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("KiB/s", point.value)
                )
                .foregroundStyle(by: .value("Direction", point.direction))
                .interpolationMethod(.catmullRom)
            }
            .chartForegroundStyleScale(["RX": Color.purple, "TX": Color.teal])
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .frame(height: 150)
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct KubernetesClusterScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String
    private var nodes: [KubernetesNodeResource] {
        (appState.backendSnapshot?.kubernetes?.nodes ?? []).filter {
            matchesSearch(searchText, values: [$0.metadata.name, $0.internalIP, $0.kubeletVersion, $0.roles.joined(separator: " ")])
        }.sorted { $0.metadata.name.localizedCaseInsensitiveCompare($1.metadata.name) == .orderedAscending }
    }

    var body: some View {
        DetailScreenLayout(
            title: "Cluster",
            subtitle: "Control plane posture and cluster access for the selected profile.",
            symbol: WorkspaceRoute.kubernetesCluster.symbol
        ) {
            if !appState.hasColima {
                missingDependencyState
            } else if appState.selectedProfile == nil {
                missingProfileState
            } else if appState.selectedProfile?.kubernetes.enabled != true {
                SurfaceStateView(
                    title: "Kubernetes is disabled",
                    message: "Enable Kubernetes on the selected profile to surface cluster details, workloads, and services.",
                    symbol: "hexagon",
                    tone: .neutral
                ) {
                    Button("Enable Kubernetes") {
                        Task { await appState.setKubernetes(enabled: true) }
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    MetricTile(title: "Context", value: appState.selectedProfile?.kubernetes.context.nonEmpty ?? "Unavailable", icon: "point.3.connected.trianglepath.dotted")
                    MetricTile(title: "Version", value: appState.selectedProfile?.kubernetes.version.nonEmpty ?? "Default", icon: "number")
                    MetricTile(title: "Node count", value: "\(nodes.count)", icon: "server.rack")
                    MetricTile(title: "Profile state", value: appState.selectedProfile?.state.label ?? "Unknown", icon: "power")
                }

                SectionCard(
                    title: "Cluster identity",
                    subtitle: "Core attributes already available through profile status.",
                    symbol: "cube.transparent"
                ) {
                    KeyValueGrid(rows: [
                        ("Profile", appState.selectedProfile?.name ?? ""),
                        ("Context", appState.selectedProfile?.kubernetes.context ?? ""),
                        ("Version", appState.selectedProfile?.kubernetes.version.nonEmpty ?? "Default"),
                        ("Docker context", appState.selectedProfileDetail?.dockerContext ?? appState.selectedProfile?.dockerContext ?? "")
                    ])
                }

                SectionCard(
                    title: "Nodes",
                    subtitle: "Kubernetes nodes from the selected Colima context.",
                    symbol: "server.rack"
                ) {
                    if nodes.isEmpty {
                        Text(searchText.isEmpty ? "No nodes reported by kubectl." : "No nodes match the current search.")
                            .foregroundStyle(.secondary)
                    } else {
                        RecordList(columns: ["Name", "Roles", "Version", "Ready"]) {
                            ForEach(nodes) { node in
                                RecordRow(
                                    leading: node.metadata.name,
                                    secondary: node.roles.isEmpty ? "worker" : node.roles.joined(separator: ", "),
                                    tertiary: node.kubeletVersion,
                                    trailing: node.conditions["Ready"] ?? "Unknown",
                                    tone: node.health == .healthy ? .success : .warning
                                )
                            }
                        }
                    }
                }

                SectionCard(
                    title: "Operator actions",
                    subtitle: "Low-friction controls for cluster lifecycle.",
                    symbol: "switch.2"
                ) {
                    HStack {
                        Button("Restart Profile") {
                            Task { await appState.restartSelected() }
                        }
                        .disabled(appState.activeOperation != nil)

                        Button("Disable Kubernetes") {
                            Task { await appState.setKubernetes(enabled: false) }
                        }
                        .disabled(appState.activeOperation != nil)
                    }
                }
            }
        }
    }

    private var missingDependencyState: some View {
        SurfaceStateView(
            title: "Cluster state unavailable",
            message: "Colima diagnostics must complete before Kubernetes status can be displayed.",
            symbol: "hexagon",
            tone: .warning
        )
    }

    private var missingProfileState: some View {
        SurfaceStateView(
            title: "Select a profile",
            message: "Kubernetes cluster state is derived from the selected Colima profile.",
            symbol: "rectangle.stack",
            tone: .info
        )
    }
}

struct KubernetesWorkloadsScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String
    private var pods: [KubernetesPodResource] {
        (appState.backendSnapshot?.kubernetes?.pods ?? []).filter {
            matchesSearch(searchText, values: [$0.metadata.name, $0.metadata.namespace ?? "", $0.phase, $0.nodeName])
        }.sorted { "\($0.metadata.namespace ?? "default")/\($0.metadata.name)".localizedCaseInsensitiveCompare("\($1.metadata.namespace ?? "default")/\($1.metadata.name)") == .orderedAscending }
    }
    private var deployments: [KubernetesDeploymentResource] {
        (appState.backendSnapshot?.kubernetes?.deployments ?? []).filter {
            matchesSearch(searchText, values: [$0.metadata.name, $0.metadata.namespace ?? ""])
        }.sorted { "\($0.metadata.namespace ?? "default")/\($0.metadata.name)".localizedCaseInsensitiveCompare("\($1.metadata.namespace ?? "default")/\($1.metadata.name)") == .orderedAscending }
    }

    var body: some View {
        DetailScreenLayout(
            title: "Workloads",
            subtitle: "Pods and deployments from the selected Colima Kubernetes context.",
            symbol: WorkspaceRoute.kubernetesWorkloads.symbol
        ) {
            if !appState.hasColima {
                missingDependencyState
            } else if appState.selectedProfile == nil {
                missingProfileState
            } else if appState.selectedProfile?.kubernetes.enabled != true {
                kubernetesDisabledState
            } else {
                SearchSummaryView(query: searchText, resultCount: pods.count + deployments.count, scopeLabel: WorkspaceRoute.kubernetesWorkloads.searchScopeLabel)
                SectionCard(title: "Pods", subtitle: "Pod health and placement across namespaces.", symbol: "rectangle.3.group") {
                    if pods.isEmpty {
                        Text(searchText.isEmpty ? "No pods reported by kubectl." : "No pods match the current search.")
                            .foregroundStyle(.secondary)
                    } else {
                        RecordList(columns: ["Name", "Namespace", "Node", "Phase"]) {
                            ForEach(pods) { pod in
                                RecordRow(
                                    leading: pod.metadata.name,
                                    secondary: pod.metadata.namespace ?? "default",
                                    tertiary: pod.nodeName,
                                    trailing: pod.phase,
                                    tone: pod.health == .healthy ? .success : pod.health == .error ? .critical : .warning
                                )
                            }
                        }
                    }
                }
                SectionCard(title: "Deployments", subtitle: "Replica readiness by namespace.", symbol: "square.3.layers.3d") {
                    if deployments.isEmpty {
                        Text(searchText.isEmpty ? "No deployments reported by kubectl." : "No deployments match the current search.")
                            .foregroundStyle(.secondary)
                    } else {
                        RecordList(columns: ["Name", "Namespace", "Ready", "Updated"]) {
                            ForEach(deployments) { deployment in
                                RecordRow(
                                    leading: deployment.metadata.name,
                                    secondary: deployment.metadata.namespace ?? "default",
                                    tertiary: "\(deployment.readyReplicas)/\(deployment.desiredReplicas)",
                                    trailing: "\(deployment.updatedReplicas)",
                                    tone: deployment.health == .healthy ? .success : .warning
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var missingDependencyState: some View {
        SurfaceStateView(title: "Workloads unavailable", message: "Resolve Colima diagnostics first.", symbol: "square.3.layers.3d.slash", tone: .warning)
    }
    private var missingProfileState: some View {
        SurfaceStateView(title: "No profile selected", message: "Select a profile before inspecting Kubernetes workloads.", symbol: "rectangle.stack", tone: .info)
    }
    private var kubernetesDisabledState: some View {
        SurfaceStateView(title: "Kubernetes is disabled", message: "Enable Kubernetes on the selected profile to query workloads.", symbol: "hexagon", tone: .neutral)
    }
}

struct KubernetesServicesScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String
    private var services: [KubernetesServiceResource] {
        (appState.backendSnapshot?.kubernetes?.services ?? []).filter {
            matchesSearch(searchText, values: [$0.metadata.name, $0.metadata.namespace ?? "", $0.type, $0.clusterIP] + $0.ports)
        }.sorted { "\($0.metadata.namespace ?? "default")/\($0.metadata.name)".localizedCaseInsensitiveCompare("\($1.metadata.namespace ?? "default")/\($1.metadata.name)") == .orderedAscending }
    }

    var body: some View {
        DetailScreenLayout(
            title: "Services",
            subtitle: "Cluster services and ports from the selected Colima Kubernetes context.",
            symbol: WorkspaceRoute.kubernetesServices.symbol
        ) {
            if !appState.hasColima {
                missingDependencyState
            } else if appState.selectedProfile == nil {
                missingProfileState
            } else if appState.selectedProfile?.kubernetes.enabled != true {
                kubernetesDisabledState
            } else {
                SearchSummaryView(query: searchText, resultCount: services.count, scopeLabel: WorkspaceRoute.kubernetesServices.searchScopeLabel)
                SectionCard(title: "Services", subtitle: "Service type, cluster IP, and exposed ports.", symbol: "point.3.connected.trianglepath.dotted") {
                    if services.isEmpty {
                        Text(searchText.isEmpty ? "No services reported by kubectl." : "No services match the current search.")
                            .foregroundStyle(.secondary)
                    } else {
                        RecordList(columns: ["Name", "Namespace", "Type", "Ports"]) {
                            ForEach(services) { service in
                                RecordRow(
                                    leading: service.metadata.name,
                                    secondary: service.metadata.namespace ?? "default",
                                    tertiary: service.type.isEmpty ? service.clusterIP : service.type,
                                    trailing: service.ports.joined(separator: ", ")
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var missingDependencyState: some View {
        SurfaceStateView(title: "Services unavailable", message: "Resolve Colima diagnostics first.", symbol: "point.3.connected.trianglepath.dotted", tone: .warning)
    }
    private var missingProfileState: some View {
        SurfaceStateView(title: "No profile selected", message: "Select a profile before inspecting cluster services.", symbol: "rectangle.stack", tone: .info)
    }
    private var kubernetesDisabledState: some View {
        SurfaceStateView(title: "Kubernetes is disabled", message: "Enable Kubernetes on the selected profile to query services.", symbol: "hexagon", tone: .neutral)
    }
}

struct ProfilesScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String

    private var filteredProfiles: [ColimaProfile] {
        appState.profiles.filter {
            matchesSearch(searchText, values: [
                $0.name,
                $0.runtime?.label ?? "",
                $0.state.label,
                $0.kubernetes.context
            ])
        }
    }

    var body: some View {
        DetailScreenLayout(
            title: "Profiles",
            subtitle: "Colima profile roster, quick lifecycle controls, and configuration entry points.",
            symbol: WorkspaceRoute.profiles.symbol,
            accessory: {
                HStack(spacing: 10) {
                    Button("Create Profile") {
                        appState.createProfile()
                    }
                    Button("Edit Selected") {
                        appState.editSelectedProfile()
                    }
                    .disabled(appState.selectedProfile == nil)
                }
            }
        ) {
            if appState.profiles.isEmpty {
                SurfaceStateView(
                    title: "No profiles configured",
                    message: "Create a Colima profile to start managing runtimes, mounts, and Kubernetes variants from the desktop UI.",
                    symbol: "rectangle.stack.badge.plus",
                    tone: .info
                ) {
                    Button("Create Profile") {
                        appState.createProfile()
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    MetricTile(title: "Profiles", value: "\(appState.profiles.count)", icon: "rectangle.stack")
                    MetricTile(title: "Running", value: "\(appState.profiles.filter { $0.state == .running }.count)", icon: "play.circle")
                    MetricTile(title: "Kubernetes enabled", value: "\(appState.profiles.filter { $0.kubernetes.enabled }.count)", icon: "hexagon")
                    MetricTile(title: "Runtimes", value: "\(Set(appState.profiles.compactMap { $0.runtime?.label }).count)", icon: "server.rack")
                }

                SearchSummaryView(query: searchText, resultCount: filteredProfiles.count, scopeLabel: WorkspaceRoute.profiles.searchScopeLabel)

                SectionCard(
                    title: "Profile roster",
                    subtitle: "Select, inspect, and switch between local Colima profiles.",
                    symbol: "list.bullet.rectangle"
                ) {
                    VStack(spacing: 0) {
                        ForEach(filteredProfiles) { profile in
                            ProfileRosterRow(profile: profile, isSelected: profile.id == appState.selectedProfileID) {
                                selectProfile(profile)
                            }
                            if profile.id != filteredProfiles.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                if let selectedProfile = appState.selectedProfile {
                    SectionCard(
                        title: "Selected profile paths",
                        subtitle: "Configuration entry points already available on the profile model.",
                        symbol: "doc.badge.gearshape"
                    ) {
                        KeyValueGrid(rows: [
                            ("Profile config", selectedProfile.configurationPaths.profileConfiguration.path),
                            ("Template", selectedProfile.configurationPaths.template.path),
                            ("SSH config", selectedProfile.configurationPaths.sshConfiguration.path),
                            ("Lima override", selectedProfile.configurationPaths.limaOverride.path)
                        ])
                    }
                }
            }
        }
    }

    private func selectProfile(_ profile: ColimaProfile) {
        appState.selectedProfileID = profile.id
        Task { await appState.refreshProfile(profile.id) }
    }
}

struct ActivityScreen: View {
    @EnvironmentObject private var appState: AppState
    let searchText: String

    private var filteredCommands: [CommandLogEntry] {
        appState.commandLog.filter {
            matchesSearch(searchText, values: [$0.command, $0.output, $0.status.label])
        }
    }

    var body: some View {
        DetailScreenLayout(
            title: "Activity",
            subtitle: "Command history, live operation feedback, and raw output for operator workflows.",
            symbol: WorkspaceRoute.activity.symbol,
            accessory: {
                Button("Refresh") {
                    Task { await appState.refreshAll() }
                }
                .disabled(appState.isRefreshing)
            }
        ) {
            if let activeOperation = appState.activeOperation {
                StatusBanner(
                    title: "Command running",
                    message: activeOperation,
                    symbol: "terminal",
                    tone: .info
                )
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                MetricTile(title: "Total commands", value: "\(appState.commandLog.count)", icon: "terminal")
                MetricTile(title: "Failures", value: "\(appState.commandLog.filter { $0.status.isFailure }.count)", icon: "exclamationmark.triangle", tone: appState.commandLog.contains(where: { $0.status.isFailure }) ? .warning : .neutral)
                MetricTile(title: "Running", value: "\(appState.commandLog.filter { $0.status.isRunning }.count)", icon: "bolt.horizontal")
                MetricTile(title: "Logs", value: appState.logs.isEmpty ? "Idle" : "Captured", icon: "doc.plaintext")
            }

            SearchSummaryView(query: searchText, resultCount: filteredCommands.count, scopeLabel: WorkspaceRoute.activity.searchScopeLabel)

            if filteredCommands.isEmpty {
                SurfaceStateView(
                    title: searchText.isEmpty ? "No command history yet" : "No matching activity",
                    message: searchText.isEmpty ? "Lifecycle actions and profile mutations will appear here with terminal output." : "Adjust the search or run another command to populate this view.",
                    symbol: "terminal",
                    tone: searchText.isEmpty ? .neutral : .warning
                )
            } else {
                SectionCard(
                    title: "Command history",
                    subtitle: "Most recent operations first, using the existing AppState command log.",
                    symbol: "clock"
                ) {
                    VStack(spacing: 0) {
                        ForEach(filteredCommands) { entry in
                            CommandEntryRow(entry: entry)
                            if entry.id != filteredCommands.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            SectionCard(
                title: "Terminal output",
                subtitle: "Latest log capture for the selected profile.",
                symbol: "chevron.left.forwardslash.chevron.right"
            ) {
                TerminalLogView(text: appState.logs, minHeight: 220)
            }
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case kubernetes
    case networking
    case integrations
    case advanced

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .kubernetes: "hexagon"
        case .networking: "network"
        case .integrations: "link.badge.plus"
        case .advanced: "slider.horizontal.3"
        }
    }
}

struct SettingsWindowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPane: SettingsPane = .general

    var body: some View {
        TabView(selection: $selectedPane) {
            ForEach(SettingsPane.allCases) { pane in
                SettingsPaneContent(pane: pane)
                    .environmentObject(appState)
                    .tabItem {
                        Label(pane.title, systemImage: pane.symbol)
                    }
                    .tag(pane)
            }
        }
        .tabViewStyle(.automatic)
        .frame(width: 620, height: 440)
    }
}

private struct SettingsPaneContent: View {
    @EnvironmentObject private var appState: AppState
    let pane: SettingsPane

    var body: some View {
        Form {
            switch pane {
            case .general:
                Section("General") {
                    Toggle("Auto refresh", isOn: $appState.autoRefresh)
                        .toggleStyle(.switch)
                    Picker("Auto refresh frequency", selection: $appState.autoRefreshFrequency) {
                        ForEach(AutoRefreshFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)
                    Toggle("Live event feeds (experimental)", isOn: $appState.useEventBus)
                        .toggleStyle(.switch)
                        .help("When on, container/pod/log updates arrive via live feeds instead of polling. Restart the app after changing.")
                    Toggle("Stream command output", isOn: $appState.useStreamingCommandOutput)
                        .toggleStyle(.switch)
                        .help("When on, colima lifecycle commands stream output live to the Activity view.")
                    LabeledContent("Selected profile", value: appState.selectedProfile?.name ?? "None")
                    LabeledContent("Active section", value: appState.selectedSection.title)
                    LabeledContent("Refresh state", value: appState.isRefreshing ? "Refreshing" : "Idle")
                }
            case .kubernetes:
                Section("Kubernetes") {
                    LabeledContent("Enabled", value: appState.selectedProfile?.kubernetes.enabled == true ? "Yes" : "No")
                    LabeledContent("Version", value: appState.selectedProfile?.kubernetes.version.nonEmpty ?? "Default")
                    LabeledContent("Context", value: appState.selectedProfile?.kubernetes.context.nonEmpty ?? "Unavailable")
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
            case .networking:
                Section("Networking") {
                    LabeledContent("Docker context", value: appState.selectedProfileDetail?.dockerContext ?? appState.selectedProfile?.dockerContext ?? "")
                    LabeledContent("Address", value: appState.selectedProfileDetail?.networkAddress ?? appState.selectedProfile?.ipAddress ?? "")
                    LabeledContent("Socket", value: appState.selectedProfileDetail?.socket ?? appState.selectedProfile?.socket ?? "")
                    LabeledContent("Mount type", value: appState.selectedProfile?.mountType?.label ?? "Unavailable")
                }
            case .integrations:
                Section("Integrations") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.diagnostics.tools) { tool in
                            ToolRow(tool: tool)
                        }
                    }
                }
            case .advanced:
                Section("Advanced") {
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
                    LabeledContent("Command history", value: "\(appState.commandLog.count) entries")
                    LabeledContent("Logs captured", value: appState.logs.isEmpty ? "No" : "Yes")
                    LabeledContent("Diagnostics messages", value: "\(appState.diagnostics.messages.count)")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 10)
    }
}

struct DiagnosticsScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        DetailScreenLayout(
            title: "Diagnostics",
            subtitle: "Dependency checks, runtime status, and environment errors.",
            symbol: WorkspaceRoute.diagnostics.symbol,
            accessory: {
                Button("Run Checks") {
                    Task { await appState.refreshAll() }
                }
                .disabled(appState.isRefreshing)
            }
        ) {
            if appState.isRefreshing {
                StatusBanner(
                    title: "Refreshing diagnostics",
                    message: "Re-running tool discovery and runtime inspection.",
                    symbol: "arrow.clockwise.circle",
                    tone: .info
                )
            }

            SectionCard(
                title: "Tools",
                subtitle: "Command-line dependencies detected for this workspace.",
                symbol: "wrench.and.screwdriver"
            ) {
                if appState.diagnostics.tools.isEmpty {
                    Text("No tool checks captured yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.diagnostics.tools) { tool in
                        ToolRow(tool: tool)
                    }
                }
            }

            SectionCard(
                title: "Runtime status",
                subtitle: "Current Colima and Docker availability.",
                symbol: "externaldrive"
            ) {
                KeyValueGrid(rows: [
                    ("Colima profile", appState.diagnostics.colima.profileName),
                    ("Colima state", appState.diagnostics.colima.state.label),
                    ("Colima error", appState.diagnostics.colima.error),
                    ("Docker available", appState.diagnostics.docker.available ? "Yes" : "No"),
                    ("Docker context", appState.diagnostics.docker.context),
                    ("Docker version", appState.diagnostics.docker.version),
                    ("Docker error", appState.diagnostics.docker.error)
                ])
            }

            SectionCard(
                title: "Messages",
                subtitle: "Additional notes collected during diagnostics.",
                symbol: "text.bubble"
            ) {
                if appState.diagnostics.messages.isEmpty {
                    Text("No diagnostic messages.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.diagnostics.messages, id: \.self) { message in
                            Text(message)
                        }
                    }
                }
            }
        }
    }
}

private struct CommandEntryRow: View {
    let entry: CommandLogEntry
    @State private var isOutputExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.command)
                    .fontWeight(.medium)
                Spacer()
                if entry.status.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 12, height: 12)
                }
                Text(entry.status.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusTone.foregroundColor)
            }
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !entry.output.isEmpty {
                Text(entry.output)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(isOutputExpanded ? nil : 4)
                    .textSelection(.enabled)
                Button(isOutputExpanded ? "Collapse output" : "Expand output") {
                    isOutputExpanded.toggle()
                }
                .font(.caption)
                .buttonStyle(.link)
            }
        }
        .padding(.vertical, 10)
    }

    private var statusTone: WorkspaceTone {
        switch entry.status {
        case .running:
            .info
        case .succeeded:
            .success
        case .failed:
            .critical
        }
    }
}

private struct ProfileRosterRow: View {
    let profile: ColimaProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                StatusDot(state: profile.state)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .fontWeight(.medium)
                    Text([profile.runtime?.label, profile.kubernetes.enabled ? "Kubernetes" : nil].compactMap { $0 }.joined(separator: " - "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(profile.state.label)
                        .foregroundStyle(tone(for: profile.state).foregroundColor)
                    Text("\(profile.resources?.cpu ?? 0) CPU / \(profile.resources?.memoryGiB ?? 0) GiB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private func matchesSearch(_ query: String, values: [String]) -> Bool {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return true }
    let normalizedNeedle = needle.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let haystack = values.joined(separator: " ").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    return haystack.contains(normalizedNeedle)
}

private func normalized(_ value: Int, against maximum: Int) -> Double {
    guard maximum > 0 else { return 0 }
    return min(Double(value) / Double(maximum), 1)
}

private func normalizedBlockIOProgress(_ sample: RuntimeUsageSample, history: [RuntimeUsageSample]) -> Double {
    let value = sample.blockReadBytes + sample.blockWriteBytes
    let maximum = history
        .map { $0.blockReadBytes + $0.blockWriteBytes }
        .max() ?? value
    guard maximum > 0 else { return 0 }
    return min(max(value / maximum, 0), 1)
}

private func formatPercent(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(value >= 10 ? 0 : 1))) + "%"
}

private func formatBytes(_ bytes: Double) -> String {
    let units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var value = max(bytes, 0)
    var index = 0
    while value >= 1024, index < units.count - 1 {
        value /= 1024
        index += 1
    }
    let fractionLength = value >= 10 || index == 0 ? 0 : 1
    return value.formatted(.number.precision(.fractionLength(fractionLength))) + " " + units[index]
}

private func formatRate(_ bytesPerSecond: Double) -> String {
    formatBytes(bytesPerSecond) + "/s"
}

private func relativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

private func networkRateText(current: RuntimeUsageSample?, previous: RuntimeUsageSample?) -> String? {
    guard let current else { return nil }
    guard let previous else {
        return formatBytes(current.networkReceiveBytes + current.networkTransmitBytes) + " I/O"
    }
    let elapsed = current.collectedAt.timeIntervalSince(previous.collectedAt)
    guard elapsed > 0 else { return formatBytes(current.networkReceiveBytes + current.networkTransmitBytes) + " I/O" }
    let receive = max(current.networkReceiveBytes - previous.networkReceiveBytes, 0) / elapsed
    let transmit = max(current.networkTransmitBytes - previous.networkTransmitBytes, 0) / elapsed
    return "\(formatRate(receive)) down / \(formatRate(transmit)) up"
}

private func trafficRatePoints(from history: [RuntimeUsageSample]) -> [RuntimeTrafficPoint] {
    guard history.count >= 2 else { return [] }
    return zip(history, history.dropFirst()).flatMap { previous, current in
        let elapsed = current.collectedAt.timeIntervalSince(previous.collectedAt)
        guard elapsed > 0 else { return [RuntimeTrafficPoint]() }
        let receive = max(current.networkReceiveBytes - previous.networkReceiveBytes, 0) / elapsed / 1024
        let transmit = max(current.networkTransmitBytes - previous.networkTransmitBytes, 0) / elapsed / 1024
        return [
            RuntimeTrafficPoint(date: current.collectedAt, direction: "RX", value: receive),
            RuntimeTrafficPoint(date: current.collectedAt, direction: "TX", value: transmit)
        ]
    }
}

private func tone(for state: ProfileState) -> WorkspaceTone {
    switch state {
    case .running:
        .success
    case .starting, .stopping:
        .info
    case .degraded, .broken:
        .warning
    case .stopped, .unknown:
        .neutral
    }
}

private extension CommandLogEntry.Status {
    var label: String {
        switch self {
        case .running:
            "Running"
        case .succeeded:
            "Succeeded"
        case .failed:
            "Failed"
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}
