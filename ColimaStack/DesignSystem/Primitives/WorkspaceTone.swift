//
//  WorkspaceTone.swift
//  ColimaStack
//
//  The five "tones" used to communicate semantic state across the app:
//  neutral, info, success, warning, and critical. Each tone maps to a
//  pair of `ColorRole`s (a foreground and a tinted background) so the
//  visual treatment is consistent everywhere.
//

import SwiftUI

public enum WorkspaceTone {
    case neutral
    case info
    case success
    case warning
    case critical

    /// The semantic color role used for foreground glyphs and text
    /// painted in this tone.
    public var foregroundColorRole: DesignSystem.ColorRole {
        switch self {
        case .neutral: return .textSecondary
        case .info: return .statusInfo
        case .success: return .statusSuccess
        case .warning: return .statusWarning
        case .critical: return .statusCritical
        }
    }

    /// A tinted background for the tone. Uses the foreground color at
    /// ~12% opacity so the banner still reads as a card.
    @ViewBuilder
    public func backgroundColor(role: (DesignSystem.ColorRole) -> Color) -> some View {
        role(foregroundColorRole).opacity(0.12)
    }

    /// The legacy `Color` accessor retained for code that has not yet
    /// been migrated to `ColorRole`. Returns the foreground tint.
    public var foregroundColor: Color {
        switch self {
        case .neutral: return .secondary
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    /// The legacy `Color` background retained for compatibility with
    /// the existing `WorkspaceComponents.swift` views.
    public var backgroundColor: Color {
        switch self {
        case .neutral: return Color(nsColor: .controlBackgroundColor)
        case .info: return Color.blue.opacity(0.12)
        case .success: return Color.green.opacity(0.12)
        case .warning: return Color.orange.opacity(0.14)
        case .critical: return Color.red.opacity(0.12)
        }
    }
}
