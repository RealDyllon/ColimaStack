//
//  ColimaStackUITestsLaunchTests.swift
//  ColimaStackUITests
//
//  Created by Dyllon on 25/4/26.
//

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
        app.launchArguments = ["--mock-data", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        ensureMainWindow(in: app)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
