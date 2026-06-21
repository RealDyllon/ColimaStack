//
//  OnboardingStateTests.swift
//  ColimaStackTests
//
//  Tests for the onboarding state machine and the
//  colimastack.didCompleteOnboarding UserDefaults flag.
//

import XCTest
@testable import ColimaStack

final class OnboardingStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        OnboardingState.reset()
    }

    override func tearDown() {
        OnboardingState.reset()
        super.tearDown()
    }

    func testHasCompletedDefault() {
        XCTAssertFalse(OnboardingState.hasCompleted)
    }

    func testMarkCompleted() {
        OnboardingState.markCompleted()
        XCTAssertTrue(OnboardingState.hasCompleted)
    }

    func testReset() {
        OnboardingState.markCompleted()
        XCTAssertTrue(OnboardingState.hasCompleted)
        OnboardingState.reset()
        XCTAssertFalse(OnboardingState.hasCompleted)
    }

    func testOnboardingStepOrdering() {
        let all = OnboardingStep.allCases
        XCTAssertEqual(all.first, .welcome)
        XCTAssertEqual(all.last, .success)
        XCTAssertEqual(all.count, 4)
    }

    func testOnboardingStepTitles() {
        XCTAssertEqual(OnboardingStep.welcome.title, "Welcome")
        XCTAssertEqual(OnboardingStep.dependencies.title, "Dependencies")
        XCTAssertEqual(OnboardingStep.createProfile.title, "Create profile")
        XCTAssertEqual(OnboardingStep.success.title, "Ready")
    }
}
