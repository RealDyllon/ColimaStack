//
//  MarketingScreenshotUITests.swift
//  ColimaStackUITests
//

import XCTest

final class MarketingScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        hideKnownInterruptingApps()
        terminateRunningColimaStack()
    }

    override func tearDownWithError() throws {
        terminateRunningColimaStack()
    }

    @MainActor
    func testCaptureMarketingScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-data", "--marketing-screenshots", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let window = ensureMainWindow(in: app)

        let outputDirectory = try Self.prepareScreenshotsDirectory()
        for scene in ScreenshotScene.marketingScenes {
            try capture(scene, in: app, window: window, outputDirectory: outputDirectory)
        }
    }

    @MainActor
    private func capture(
        _ scene: ScreenshotScene,
        in app: XCUIApplication,
        window: XCUIElement,
        outputDirectory: URL
    ) throws {
        let route = app.descendants(matching: .any)[scene.routeIdentifier]
        XCTAssertTrue(route.waitForExistence(timeout: 5), "Missing route \(scene.routeIdentifier)")
        app.activate()
        route.click()

        XCTAssertTrue(app.staticTexts[scene.expectedText].waitForExistence(timeout: 5), "Missing marker \(scene.expectedText)")
        waitForStableUI(in: app)

        let screenshot = window.screenshot()
        let outputURL = outputDirectory.appendingPathComponent(scene.fileName)
        try screenshot.pngRepresentation.write(to: outputURL, options: [.atomic])

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = scene.attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func prepareScreenshotsDirectory(filePath: String = #filePath) throws -> URL {
        let fileManager = FileManager.default
        let sourceURL = URL(fileURLWithPath: filePath)
        var directory = sourceURL.deletingLastPathComponent()

        while directory.path != "/" {
            let assetsDirectory = directory.appendingPathComponent("assets", isDirectory: true)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: assetsDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let screenshotsDirectory = assetsDirectory.appendingPathComponent("screenshots", isDirectory: true)
                try fileManager.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
                return screenshotsDirectory
            }
            directory.deleteLastPathComponent()
        }

        throw ScreenshotError.repositoryRootNotFound
    }

    @MainActor
    private func waitForStableUI(in app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline, app.progressIndicators.count > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
    }
}

private struct ScreenshotScene {
    var routeIdentifier: String
    var expectedText: String
    var fileName: String
    var attachmentName: String

    static let marketingScenes: [ScreenshotScene] = [
        ScreenshotScene(routeIdentifier: "route.overview", expectedText: "Runtime context", fileName: "01-overview.png", attachmentName: "Marketing - Overview"),
        ScreenshotScene(routeIdentifier: "route.containers", expectedText: "Engine access", fileName: "02-containers.png", attachmentName: "Marketing - Containers"),
        ScreenshotScene(routeIdentifier: "route.monitor", expectedText: "Current usage", fileName: "03-monitor.png", attachmentName: "Marketing - Monitor"),
        ScreenshotScene(routeIdentifier: "route.kubernetesCluster", expectedText: "Cluster identity", fileName: "04-kubernetes-cluster.png", attachmentName: "Marketing - Kubernetes Cluster"),
        ScreenshotScene(routeIdentifier: "route.kubernetesWorkloads", expectedText: "Pods", fileName: "05-kubernetes-workloads.png", attachmentName: "Marketing - Kubernetes Workloads"),
        ScreenshotScene(routeIdentifier: "route.activity", expectedText: "Terminal output", fileName: "06-activity.png", attachmentName: "Marketing - Activity")
    ]
}

private enum ScreenshotError: Error {
    case repositoryRootNotFound
}
