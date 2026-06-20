//
//  EmptyStateView.swift
//  ColimaStack
//
//  The single empty/loading/error surface for the app. Every screen
//  that can show a list, a table, or a section uses `EmptyStateView`
//  for its empty/loading/error/unavailable/disabled state. Replaces
//  the legacy `SurfaceStateView`.
//

import SwiftUI

/// The kind of empty state to render. Each kind tunes the icon
/// affordance, the default color tone, and the copy tone.
public enum EmptyStateKind {
    case noResults
    case noData
    case loading
    case error
    case unavailable
    case disabled

    var defaultTone: WorkspaceTone {
        switch self {
        case .noResults, .noData, .loading, .disabled: return .neutral
        case .error: return .critical
        case .unavailable: return .warning
        }
    }
}

public struct EmptyStateView<Actions: View>: View {
    let kind: EmptyStateKind
    let title: String
    let message: String
    let symbol: String?
    let tone: WorkspaceTone
    @ViewBuilder private let actions: Actions

    @Environment(\.colorRole) private var colorRole

    public init(
        kind: EmptyStateKind,
        title: String,
        message: String,
        symbol: String? = nil,
        tone: WorkspaceTone? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.symbol = symbol
        self.tone = tone ?? kind.defaultTone
        self.actions = actions()
    }

    public init(
        kind: EmptyStateKind,
        title: String,
        message: String,
        symbol: String? = nil,
        tone: WorkspaceTone? = nil
    ) where Actions == EmptyView {
        self.init(
            kind: kind,
            title: title,
            message: message,
            symbol: symbol,
            tone: tone,
            actions: { EmptyView() }
        )
    }

    /// Backwards-compatible initializer that infers the kind from the
    /// tone. Retained so the many existing call sites that pass a tone
    /// (and no kind) continue to compile while the migration is in
    /// progress. New code SHALL pass an explicit `kind`.
    public init(
        title: String,
        message: String,
        symbol: String,
        tone: WorkspaceTone,
        @ViewBuilder actions: () -> Actions
    ) {
        let inferredKind: EmptyStateKind
        switch tone {
        case .critical: inferredKind = .error
        case .warning: inferredKind = .unavailable
        case .info: inferredKind = .loading
        case .success, .neutral: inferredKind = .noData
        }
        self.kind = inferredKind
        self.title = title
        self.message = message
        self.symbol = symbol
        self.tone = tone
        self.actions = actions()
    }

    public init(
        title: String,
        message: String,
        symbol: String,
        tone: WorkspaceTone
    ) where Actions == EmptyView {
        self.init(
            title: title,
            message: message,
            symbol: symbol,
            tone: tone,
            actions: { EmptyView() }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md.rawValue) {
            illustration
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .textStyle(.title3)
            Text(message)
                .foregroundStyle(colorRole(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg.rawValue)
        .background(tone.backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card.rawValue)
                .stroke(colorRole(.borderSubtle), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card.rawValue))
    }

    @ViewBuilder
    private var illustration: some View {
        switch kind {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(height: DesignSystem.IconSize.hero)
        default:
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: DesignSystem.IconSize.hero, weight: .semibold))
                    .foregroundStyle(colorRole(tone.foregroundColorRole))
                    .frame(height: DesignSystem.IconSize.hero)
            }
        }
    }
}

// MARK: - Backwards-compat alias
//
// `SurfaceStateView` was the previous name. It is preserved here as a
// typealias so existing call sites compile unchanged; new code SHALL
// use `EmptyStateView`.
public typealias SurfaceStateView = EmptyStateView
