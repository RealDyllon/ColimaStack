//
//  IconBadge.swift
//  ColimaStack
//
//  A rounded-rectangle backdrop with a leading icon and optional
//  trailing text/count. Used for status pills, environment tags, and
//  similar small accent surfaces.
//

import SwiftUI

public struct IconBadge: View {
    let symbol: String
    let label: String?
    var tone: WorkspaceTone = .neutral

    @Environment(\.colorRole) private var colorRole

    public init(symbol: String, label: String? = nil, tone: WorkspaceTone = .neutral) {
        self.symbol = symbol
        self.label = label
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            if let label {
                Text(label)
                    .textStyle(.caption)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(colorRole(tone.foregroundColorRole))
        .background(
            Capsule()
                .fill(colorRole(tone.foregroundColorRole).opacity(0.12))
        )
    }
}
