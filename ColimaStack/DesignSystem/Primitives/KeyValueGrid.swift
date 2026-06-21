//
//  KeyValueGrid.swift
//  ColimaStack
//
//  A two-column grid of (label, value) rows used in diagnostic and
//  detail panels. Every row supports a context menu with Copy, and
//  values are selectable and middle-truncated by default.
//

import AppKit
import SwiftUI

public struct KeyValueGrid: View {
    let rows: [(String, String)]

    @Environment(\.colorRole) private var colorRole

    public init(rows: [(String, String)]) {
        self.rows = rows
    }

    public var body: some View {
        Grid(alignment: .leading, horizontalSpacing: DesignSystem.Spacing.lg.rawValue, verticalSpacing: DesignSystem.Spacing.sm.rawValue) {
            ForEach(rows.filter { !$0.0.isEmpty }, id: \.0) { key, value in
                GridRow {
                    Text(key)
                        .foregroundStyle(colorRole(.textSecondary))
                    Text(value.isEmpty ? "Unavailable" : value)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contextMenu {
                            Button("Copy") {
                                copyToPasteboard(value)
                            }
                            .disabled(value.isEmpty)
                        }
                }
            }
        }
    }
}

// `copyToPasteboard` is defined in `ColimaStack/Views/WorkspaceComponents.swift`
// (file-internal `func` made module-internal). This file consumes it.
