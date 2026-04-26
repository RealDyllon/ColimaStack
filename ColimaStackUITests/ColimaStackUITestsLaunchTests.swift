//
//  ColimaStackUITestsLaunchTests.swift
//  ColimaStackUITests
//
//  Created by Dyllon on 25/4/26.
//

import AppKit
import XCTest

final class ColimaStackUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        hideKnownInterruptingApps()
        terminateRunningColimaStack()
    }

    override func tearDownWithError() throws {
        terminateRunningColimaStack()
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-data"]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private func terminateRunningColimaStack() {
    NSRunningApplication.runningApplications(withBundleIdentifier: "io.dyllon.ColimaStack")
        .forEach { $0.forceTerminate() }
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
}

private func hideKnownInterruptingApps() {
    ["com.googlecode.iterm2", "com.apple.Terminal"].forEach { bundleIdentifier in
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .forEach { $0.hide() }
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}
