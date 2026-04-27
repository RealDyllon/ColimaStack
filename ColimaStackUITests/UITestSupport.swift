//
//  UITestSupport.swift
//  ColimaStackUITests
//

import AppKit
import XCTest

@MainActor
@discardableResult
func ensureMainWindow(in app: XCUIApplication, timeout: TimeInterval = 8) -> XCUIElement {
    app.activate()

    let refreshButton = app.buttons["toolbar.refresh"].firstMatch
    if !refreshButton.waitForExistence(timeout: 1) {
        app.typeKey("n", modifierFlags: [.command])
        app.activate()
    }

    let window = app.windows.firstMatch
    XCTAssertTrue(window.waitForExistence(timeout: timeout), "Missing main window")
    XCTAssertTrue(refreshButton.waitForExistence(timeout: timeout), "Missing main toolbar")
    return window
}

func terminateRunningColimaStack() {
    NSRunningApplication.runningApplications(withBundleIdentifier: "io.dyllon.ColimaStack")
        .forEach { $0.forceTerminate() }
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
}

func hideKnownInterruptingApps() {
    ["com.googlecode.iterm2", "com.apple.Terminal"].forEach { bundleIdentifier in
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .forEach { $0.hide() }
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}
