//
//  ColimaStackApp.swift
//  ColimaStack
//

import AppKit
import SwiftUI

@main
struct ColimaStackApp: App {
    @NSApplicationDelegateAdaptor(MockLaunchWindowDelegate.self) private var mockLaunchWindowDelegate
    @StateObject private var appState = Self.makeAppState()
    private let usesMockData = ProcessInfo.processInfo.arguments.contains("--mock-data")
    private let usesMarketingScreenshots = ProcessInfo.processInfo.arguments.contains("--marketing-screenshots")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.launch()
                    if !usesMockData {
                        await appState.runAutoRefreshLoop()
                    }
                }
        }
        .defaultSize(width: usesMarketingScreenshots ? 1280 : 1000, height: usesMarketingScreenshots ? 860 : 700)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh") {
                    Task { await appState.refreshAll() }
                }
                .keyboardShortcut("r")
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
    private static func makeAppState() -> AppState {
        if ProcessInfo.processInfo.arguments.contains("--mock-data") {
            let state = AppState.preview()
            state.autoRefresh = false
            return state
        }
        return .live()
    }

    private static func openMainWindow() {
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
        NSApp.sendAction(action, to: newWindowItem.target, from: newWindowItem)
        return
    }

    NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
    NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
}
