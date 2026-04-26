//
//  ColimaStackUITests.swift
//  ColimaStackUITests
//
//  Created by Dyllon on 25/4/26.
//

import AppKit
import XCTest

final class ColimaStackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        hideKnownInterruptingApps()
        terminateRunningColimaStack()
    }

    override func tearDownWithError() throws {
        terminateRunningColimaStack()
    }

    @MainActor
    func testPrimaryNavigationUsesMockData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-data"]
        app.launch()
        app.activate()

        XCTAssertTrue(app.buttons["toolbar.refresh"].waitForExistence(timeout: 5))

        let containersRoute = app.descendants(matching: .any)["route.containers"]
        XCTAssertTrue(containersRoute.waitForExistence(timeout: 3))
        app.activate()
        containersRoute.click()
        XCTAssertTrue(app.staticTexts["Engine access"].waitForExistence(timeout: 3))

        let kubernetesRoute = app.descendants(matching: .any)["route.kubernetesCluster"]
        XCTAssertTrue(kubernetesRoute.waitForExistence(timeout: 3))
        app.activate()
        kubernetesRoute.click()
        XCTAssertTrue(app.staticTexts["Cluster"].waitForExistence(timeout: 3))

        let activityRoute = app.descendants(matching: .any)["route.activity"]
        XCTAssertTrue(activityRoute.waitForExistence(timeout: 3))
        app.activate()
        activityRoute.click()
        XCTAssertTrue(app.staticTexts["Terminal output"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDeleteProfileRequiresTypedProfileConfirmation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-data"]
        app.launch()
        app.activate()

        let deleteButton = app.buttons["toolbar.delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()

        XCTAssertTrue(app.staticTexts["Delete default?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["This permanently deletes the Colima profile named default, including its VM and data. This cannot be undone."].exists)

        let confirmButton = app.buttons["delete.confirm"].firstMatch
        XCTAssertTrue(confirmButton.exists)
        XCTAssertFalse(confirmButton.isEnabled)

        let namedConfirmationField = app.textFields["Type default to confirm"].firstMatch
        let confirmationField = namedConfirmationField.exists ? namedConfirmationField : app.textFields.firstMatch
        XCTAssertTrue(confirmationField.waitForExistence(timeout: 3))
        confirmationField.click()
        confirmationField.typeText("default")
        XCTAssertTrue(confirmButton.isEnabled)
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
