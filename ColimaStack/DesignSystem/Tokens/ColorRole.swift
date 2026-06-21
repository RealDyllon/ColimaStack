//
//  ColorRole.swift
//  ColimaStack
//
//  Semantic color roles. Every color in the app is named for its intent
//  (text/primary, surface/raised, status/success, etc.) rather than its
//  appearance. Resolutions adapt automatically to light and dark mode
//  via `Color(nsColor:)` for system materials and explicit hex/asset
//  resolution for brand colors.
//

import SwiftUI

extension DesignSystem {
    /// Semantic color roles. Each role is named for its purpose, not
    /// its appearance. Use these instead of raw `Color.blue`/`.gray`/etc.
    public enum ColorRole {
        // MARK: Text
        case textPrimary
        case textSecondary
        case textTertiary
        case textInverse

        // MARK: Surface
        case surfaceCanvas
        case surfaceRaised
        case surfaceSunken
        case surfaceInverse

        // MARK: Border
        case borderSubtle
        case borderStrong

        // MARK: Accent
        case accentPrimary

        // MARK: Status
        case statusSuccess
        case statusWarning
        case statusCritical
        case statusInfo
        case statusNeutral
    }
}

extension DesignSystem.ColorRole {
    /// The resolved `Color` for this role in the current color scheme.
    ///
    /// The mapping intentionally uses `Color(nsColor:)` for system
    /// surfaces/text and explicit `Color(...)` values for status hues so
    /// both light and dark mode are honored and so the status hues stay
    /// consistent with the rest of macOS.
    public func resolve(colorScheme: ColorScheme) -> Color {
        switch self {
        // MARK: Text
        case .textPrimary:
            return Color(nsColor: .labelColor)
        case .textSecondary:
            return Color(nsColor: .secondaryLabelColor)
        case .textTertiary:
            return Color(nsColor: .tertiaryLabelColor)
        case .textInverse:
            return Color(nsColor: .windowBackgroundColor)

        // MARK: Surface
        case .surfaceCanvas:
            return Color(nsColor: .windowBackgroundColor)
        case .surfaceRaised:
            return Color(nsColor: .controlBackgroundColor)
        case .surfaceSunken:
            return Color(nsColor: .textBackgroundColor)
        case .surfaceInverse:
            return Color(nsColor: .labelColor)

        // MARK: Border
        case .borderSubtle:
            return Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.5 : 0.25)
        case .borderStrong:
            return Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.85 : 0.55)

        // MARK: Accent
        case .accentPrimary:
            return Color.accentColor

        // MARK: Status
        case .statusSuccess:
            return Color(nsColor: .systemGreen)
        case .statusWarning:
            return Color(nsColor: .systemOrange)
        case .statusCritical:
            return Color(nsColor: .systemRed)
        case .statusInfo:
            return Color(nsColor: .systemBlue)
        case .statusNeutral:
            return Color(nsColor: .secondaryLabelColor)
        }
    }
}

// MARK: - Environment key

private struct ColorRoleKey: EnvironmentKey {
    static let defaultValue: (DesignSystem.ColorRole) -> Color = { role in
        role.resolve(colorScheme: .light)
    }
}

extension EnvironmentValues {
    /// Resolves a `ColorRole` using the current environment. Prefer this
    /// over calling `DesignSystem.ColorRole.resolve` directly so the
    /// resolution respects the active color scheme.
    var colorRole: (DesignSystem.ColorRole) -> Color {
        get { self[ColorRoleKey.self] }
        set { self[ColorRoleKey.self] = newValue }
    }
}

private struct ColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}

extension EnvironmentValues {
    /// The active `ColorScheme` resolved at the root of the app, used by
    /// the `ColorRole.resolve(colorScheme:)` helper when the environment
    /// chain does not provide a `\.colorScheme` value.
    var resolvedColorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
}

// MARK: - Root modifier

public extension View {
    /// Inject a color-role resolver into the environment. Apply this
    /// once at the root of the app (or at a feature boundary) so that
    /// downstream views can use `\.colorRole`.
    func designSystemColorResolution() -> some View {
        modifier(DesignSystemColorResolutionModifier())
    }
}

private struct DesignSystemColorResolutionModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.colorRole, { role in
            role.resolve(colorScheme: colorScheme)
        })
    }
}
