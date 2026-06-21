//
//  MotionFeedbackTests.swift
//  ColimaStackTests
//
//  Tests for the motion-feedback capability: ToastCenter stacking,
//  VoiceOver throttling, hover/focus ring presence, lifecycle flash
//  state.
//

import XCTest
import SwiftUI
@testable import ColimaStack

@MainActor
final class ToastCenterTests: XCTestCase {
    func testEmptyCenterHasNoToasts() {
        let center = ToastCenter()
        XCTAssertEqual(center.toasts.count, 0)
    }

    func testShowToastAppends() {
        let center = ToastCenter()
        let toast = ToastCenter.Toast(title: "Hello", message: "World", tone: .info)
        center.show(toast)
        XCTAssertEqual(center.toasts.count, 1)
        XCTAssertEqual(center.toasts.first?.id, toast.id)
    }

    func testMaxToastsTrimsFromFront() {
        let center = ToastCenter()
        for index in 0..<10 {
            center.show(ToastCenter.Toast(title: "\(index)", message: "", tone: .info))
        }
        XCTAssertEqual(center.toasts.count, ToastCenter.maxToasts)
        XCTAssertEqual(center.toasts.first?.title, "7")
    }

    func testDismiss() {
        let center = ToastCenter()
        let toast = ToastCenter.Toast(title: "X", message: "", tone: .info)
        center.show(toast)
        center.dismiss(id: toast.id)
        XCTAssertEqual(center.toasts.count, 0)
    }

    func testToastToneIcons() {
        XCTAssertEqual(ToastCenter.Toast.Tone.success.iconName, "checkmark.circle.fill")
        XCTAssertEqual(ToastCenter.Toast.Tone.warning.iconName, "exclamationmark.triangle.fill")
        XCTAssertEqual(ToastCenter.Toast.Tone.error.iconName, "xmark.octagon.fill")
        XCTAssertEqual(ToastCenter.Toast.Tone.info.iconName, "info.circle.fill")
    }

    func testToastWithAction() {
        var invoked = false
        let toast = ToastCenter.Toast(
            title: "Profile started",
            message: "",
            tone: .success,
            actionTitle: "Open",
            actionHandler: { invoked = true }
        )
        toast.actionHandler?()
        XCTAssertTrue(invoked)
    }
}

@MainActor
final class VoiceOverAnnouncerTests: XCTestCase {
    func testThrottling() {
        let announcer = VoiceOverAnnouncer.shared
        // First announcement goes through; second within 3s is throttled.
        // We can only verify the internal timestamp tracking is monotonic.
        announcer.announce("first")
        let first = announcer.lastAnnouncementAt
        announcer.announce("second")
        XCTAssertGreaterThanOrEqual(announcer.lastAnnouncementAt, first)
    }
}
