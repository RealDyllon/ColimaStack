//
//  ColimaStackApp.swift
//  ColimaStack
//
//

import AppKit
import SwiftUI

@main
struct ColimaStackApp: App {
    @NSApplicationDelegateAdaptor(MockLaunchWindowDelegate.self) private var mockLaunchWindowDelegate
    @StateObject private var appState = Self.makeAppState()
    @StateObject private var eventEngine = RuntimeEventEngine()
    private let usesMockData = ProcessInfo.processInfo.arguments.contains("--mock-data")
    private let usesMarketingScreenshots = ProcessInfo.processInfo.arguments.contains("--marketing-screenshots")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(eventEngine)
                .task {
                    await appState.launch()
                    configureEventEngine()
                    eventEngine.start(appState: appState)
                    await appState.runToolCheckTimer()
                }
        }
        .defaultSize(width: usesMarketingScreenshots ? 1280 : 1100, height: usesMarketingScreenshots ? 860 : 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh") {
                    Task { await appState.refreshAll() }
                }
                .keyboardShortcut("r")

                Button("Focus Search") {
                    NotificationCenter.default.post(name: .focusWorkspaceSearch, object: nil)
                }
                .keyboardShortcut("f")
            }

            CommandGroup(after: .toolbar) {
                TableDensityMenu()
            }

            CommandGroup(replacing: .windowList) {
                WindowListMenu()
            }

            CommandGroup(after: .windowSize) {
                Divider()
                WindowListMenu()
            }
        }

        MenuBarExtra(isInserted: menuBarExtraIsInserted) {
            ColimaStackMenuBarMenu {
                Self.openMainWindow()
            }
            .environmentObject(appState)
        } label: {
            ColimaStackMenuBarLabel()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsWindowView()
                .environmentObject(appState)
        }
    }

    private var menuBarExtraIsInserted: Binding<Bool> {
        Binding(
            get: { !usesMockData },
            set: { _ in }
        )
    }

    @MainActor
    static func makeAppState() -> AppState {
        if ProcessInfo.processInfo.arguments.contains("--mock-data") {
            let state = AppState.preview()
            state.autoRefresh = false
            return state
        }
        return .live()
    }

    /// Wire the real event source factories into the engine. The factories return `nil`
    /// when a source isn't applicable (e.g. docker source for a containerd profile), and
    /// the engine skips starting that source.
    private func configureEventEngine() {
        guard !usesMockData else { return }
        eventEngine.dockerSourceFactory = { profile, status in
            DockerEventSource(profile: profile, status: status)
        }
        eventEngine.kubernetesSourceFactory = { profile, status in
            KubernetesWatchSource(profile: profile, status: status)
        }
        eventEngine.colimaSourceFactory = { profile in
            ColimaFileWatcherSource(profile: profile, colima: appState.colimaForEvents)
        }
    }

    private static func openMainWindow() {
        // Single-window policy: reuse the existing main window. Open
        // a new one only when none exists or ⌘N was pressed.
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        sendNewWindowCommand()
    }
}

private final class MockLaunchWindowDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.arguments.contains("--mock-data") else { return }
        NSApp.activate(ignoringOtherApps: true)
        openMainWindowIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.openMainWindowIfNeeded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if ProcessInfo.processInfo.arguments.contains("--mock-data"), !flag {
            openMainWindowIfNeeded()
        }
        // Activate the existing window if any. This is the single-window policy.
        if let existing = NSApp.windows.first(where: { $0.canBecomeKey }) {
            existing.makeKeyAndOrderFront(nil)
        }
        return true
    }

    private func openMainWindowIfNeeded() {
        guard !NSApp.windows.contains(where: { $0.canBecomeKey && $0.isVisible }) else { return }
        sendNewWindowCommand()
    }
}

private func sendNewWindowCommand() {
    if let newWindowItem = NSApp.mainMenu?.item(withTitle: "File")?.submenu?.item(withTitle: "New Window"),
       let action = newWindowItem.action {
        NSApp.sendAction(action, to: newWindowItem.target, from: nil)
        return
    }

    NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
    NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
}

// MARK: - Window > Window menu

/// Lists open windows by their current route. The system provides a
/// default version of this menu; we replace it so the entries are
/// informative.
private struct WindowListMenu: View {
    @State private var tick = 0

    var body: some View {
        let windows = NSApp.windows.filter { $0.canBecomeKey && $0.isVisible }
        if windows.isEmpty {
            Text("No open windows")
        } else {
            ForEach(Array(windows.enumerated()), id: \.offset) { index, window in
                Button {
                    window.makeKeyAndOrderFront(nil)
                } label: {
                    Text(title(for: window, index: index))
                }
            }
        }
    }

    private func title(for window: NSWindow, index: Int) -> String {
        if index == 0 {
            return "Main Window"
        }
        return "Main Window (\(window.title.isEmpty ? "untitled" : window.title))"
    }
}

extension Notification.Name {
    static let focusWorkspaceSearch = Notification.Name("focusWorkspaceSearch")
}

// MARK: - View > Table Density menu

/// `View > Table Density > Standard | Compact`. The selection writes
/// to `appState.defaultTableDensity`, which the resource tables read.
private struct TableDensityMenu: View {
    @StateObject private var appState = ColimaStackApp.makeAppState()

    var body: some View {
        Menu("Table Density") {
            ForEach(TableDensity.allCases) { density in
                Button {
                    appState.defaultTableDensity = density
                } label: {
                    HStack {
                        Text(density.label)
                        if appState.defaultTableDensity == density {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}
