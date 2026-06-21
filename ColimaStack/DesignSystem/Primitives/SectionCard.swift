//
//  SectionCard.swift
//  ColimaStack
//
//  A raised, rounded, bordered card surface used as the standard
//  container for groups of related content across the app. Every
//  detail screen in the workspace composes its body from `SectionCard`s.
//

import SwiftUI

public struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String
    @ViewBuilder private let content: Content

    @Environment(\.colorRole) private var colorRole

    public init(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md.rawValue) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm.rawValue) {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        DesignSystem.TextStyle.title3.text(title)
                    } icon: {
                        Image(systemName: symbol)
                            .foregroundStyle(colorRole(.accentPrimary))
                    }
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .textStyle(.caption)
                            .foregroundStyle(colorRole(.textSecondary))
                    }
                }
                Spacer(minLength: 0)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md.rawValue)
        .background(DesignSystem.Elevation.raised.color())
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card.rawValue)
                .stroke(colorRole(.borderSubtle), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card.rawValue))
    }
}
