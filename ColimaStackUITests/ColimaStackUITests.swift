//
//  ColimaStackUITests.swift
//  ColimaStackUITests
//
//  Created by Dyllon on 25/4/26.
//

import XCTest

final class ColimaStackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMainWindowLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-data"]
        app.launch()

        XCTAssertTrue(app.buttons["Refresh"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Overview"].exists)
        XCTAssertTrue(app.staticTexts["Containers"].exists)
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }

    @MainActor
    func testPrimaryNavigationUsesMockData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-data"]
        app.launch()

        XCTAssertTrue(app.buttons["Refresh"].waitForExistence(timeout: 5))

        app.staticTexts["Containers"].click()
        XCTAssertTrue(app.staticTexts["Engine access"].waitForExistence(timeout: 3))

        app.staticTexts["Kubernetes"].click()
        XCTAssertTrue(app.staticTexts["Cluster"].waitForExistence(timeout: 3))

        app.staticTexts["Activity"].click()
        XCTAssertTrue(app.staticTexts["Terminal output"].waitForExistence(timeout: 3))
    }
}
