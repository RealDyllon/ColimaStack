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
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-data"]
        app.launch()

        XCTAssertTrue(app.buttons["Refresh"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
