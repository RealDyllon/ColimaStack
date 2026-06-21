//
//  Motion.swift
//  ColimaStack
//
//  Motion tokens. Every animation in the app SHALL use one of these
//  durations/curves. Ad-hoc `withAnimation(.easeInOut(duration: 0.3))`
//  calls SHALL be replaced with token-based animations.
//

import SwiftUI

extension DesignSystem {
    /// Motion duration tokens (in seconds).
    public enum Motion {
        case fast
        case `default`
        case slow
    }
}

extension DesignSystem.Motion {
    /// The duration in seconds for this motion token, with the
    /// "Reduce motion" accessibility setting honored: `default` and
    /// `slow` collapse to `0` so transitions are instant; `fast`
    /// collapses to `0.05` so progress indicators still animate.
    public func duration(reduceMotion: Bool) -> Double {
        switch self {
        case .fast:
            return reduceMotion ? 0.05 : 0.15
        case .default:
            return reduceMotion ? 0.0 : 0.22
        case .slow:
            return reduceMotion ? 0.0 : 0.35
        }
    }
}

extension DesignSystem {
    /// Animation-curve tokens.
    public enum MotionCurve {
        case standard
        case emphasized
        case spring

        /// The `Animation` value for this curve, given a motion duration.
        public func animation(duration: Double) -> Animation {
            switch self {
            case .standard:
                return .easeInOut(duration: duration)
            case .emphasized:
                // macOS 14+ emphasizes curve; falls back to a soft ease.
                return .timingCurve(0.2, 0.0, 0.0, 1.0, duration: duration)
            case .spring:
                return .spring(response: 0.35, dampingFraction: 0.85)
            }
        }
    }
}

// MARK: - Environment

private struct ReduceMotionKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Whether the system "Reduce motion" accessibility setting is on.
    /// The value is set by `ReduceMotionObserver` at the root of the app.
    var prefersReducedMotion: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }
}

// MARK: - Root modifier

public extension View {
    /// Inject the reduce-motion preference from the system accessibility
    /// setting into the environment. Apply once at the root of the app.
    func observeReducedMotion() -> some View {
        modifier(ReduceMotionObserver())
    }
}

private struct ReduceMotionObserver: ViewModifier {
    @State private var reduceMotion: Bool = Self.readReduceMotion()

    func body(content: Content) -> some View {
        content
            .environment(\.prefersReducedMotion, reduceMotion)
            .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)) { _ in
                reduceMotion = Self.readReduceMotion()
            }
    }

    /// Read the system "Reduce motion" preference.
    ///
    /// `NSWorkspace.shared.accessibilityDisplayOptions` is a private
    /// KVC-backed dictionary. The legacy `value(forKey:)` accessor raises
    /// `NSUnknownKeyException` on signed/sealed builds because the
    /// dictionary doesn't expose `shouldReduceMotion` as a KVC key.
    /// We use `perform(_:)` (which never throws on bad keys) and
    /// `dict.object(forKey:)` (which returns nil rather than raising)
    /// to read it safely, and fall back to the well-known UserDefaults
    /// key that System Settings writes to.
    private static func readReduceMotion() -> Bool {
        let workspace = NSWorkspace.shared
        let selector = NSSelectorFromString("accessibilityDisplayOptions")
        if workspace.responds(to: selector),
           let dict = workspace.perform(selector)?.takeUnretainedValue() as? NSDictionary,
           let flag = dict.object(forKey: "shouldReduceMotion") as? NSNumber {
            return flag.boolValue
        }
        return UserDefaults.standard.bool(forKey: "com.apple.universalaccess reduceMotion")
    }
}
