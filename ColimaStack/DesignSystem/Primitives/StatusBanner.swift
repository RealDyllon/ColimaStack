//
//  StatusBanner.swift
//  ColimaStack
//
//  An inline, tone-tinted status message with an icon, title, message,
//  and optional trailing action. Used in the overview screen for
//  command-in-progress, warnings, and live-feed reconnect notices.
//

import SwiftUI

public struct StatusBanner<Actions: View>: View {
    let title: String
    let message: String
    let symbol: String
    let tone: WorkspaceTone
    @ViewBuilder private let actions: Actions

    @Environment(\.colorRole) private var colorRole

    public init(
        title: String,
        message: String,
        symbol: String,
        tone: WorkspaceTone,
        @ViewBuilder actions: () -> Actions
    ) {
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
        self.init(title: title, message: message, symbol: symbol, tone: tone, actions: { EmptyView() })
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md.rawValue) {
            Image(systemName: symbol)
                .foregroundStyle(colorRole(tone.foregroundColorRole))
                .textStyle(.body)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(message)
                    .textStyle(.caption)
                    .foregroundStyle(colorRole(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DesignSystem.Spacing.sm.rawValue)
            actions
        }
        .padding(DesignSystem.Spacing.md.rawValue)
        .background(tone.backgroundColor(role: colorRole))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card.rawValue)
                .stroke(colorRole(.borderSubtle), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card.rawValue))
    }
}
