//
//  MetricTile.swift
//  ColimaStack
//
//  A compact metric display: caption label, large value, optional
//  tone-driven color. Used in the overview screen's headline grid and
//  in every resource screen's top stat row.
//

import SwiftUI

public struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    var tone: WorkspaceTone = .neutral

    @Environment(\.colorRole) private var colorRole

    public init(title: String, value: String, icon: String, tone: WorkspaceTone = .neutral) {
        self.title = title
        self.value = value
        self.icon = icon
        self.tone = tone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm.rawValue) {
            Label {
                Text(title)
                    .textStyle(.caption)
                    .foregroundStyle(colorRole(.textSecondary))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(colorRole(.textSecondary))
            }
            Text(value)
                .textStyle(.title3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(valueForeground)
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

    private var valueForeground: Color {
        switch tone {
        case .neutral:
            return colorRole(.textPrimary)
        case .info:
            return colorRole(.statusInfo)
        case .success:
            return colorRole(.statusSuccess)
        case .warning:
            return colorRole(.statusWarning)
        case .critical:
            return colorRole(.statusCritical)
        }
    }
}
