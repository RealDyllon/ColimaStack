//
//  ColimaStackApp.swift
//  ColimaStack
//

import AppKit
import SwiftUI

@main
struct ColimaStackApp: App {
    @StateObject private var appState = Self.makeAppState()
    private let usesMockData = ProcessInfo.processInfo.arguments.contains("--mock-data")

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
        NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
    }
}
