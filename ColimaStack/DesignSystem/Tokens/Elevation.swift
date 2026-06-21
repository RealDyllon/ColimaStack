//
//  Elevation.swift
//  ColimaStack
//
//  Surface elevation tokens. The app uses three tiers: `canvas` (the
//  window background), `raised` (one step up — used for cards, tiles,
//  and the table), and `sunken` (one step down — used for table
//  headers, code blocks, and the terminal log). No view SHALL stack
//  more than two raised surfaces; a card inside a card is forbidden.
//

import SwiftUI

extension DesignSystem {
    /// Surface elevation tiers.
    public enum Elevation {
        case canvas
        case raised
        case sunken
    }
}

extension DesignSystem.Elevation {
    /// The background fill for this elevation. `canvas` and `sunken` use
    /// system materials; `raised` uses the system control background so
    /// cards sit visibly above the window in both light and dark mode.
    @ViewBuilder
    public func background() -> some View {
        switch self {
        case .canvas:
            // Window background — let the system material show through.
            Color.clear
        case .raised:
            // Card / tile background.
            Color(nsColor: .controlBackgroundColor)
        case .sunken:
            // Table header / terminal / code block.
            Color(nsColor: .textBackgroundColor)
        }
    }

    /// The `Color` (non-view) for this elevation, used in places that
    /// need a `Color` value (e.g. `.background()` with a shape, or
    /// `.fill()` on a path).
    public func color() -> Color {
        switch self {
        case .canvas:
            return Color(nsColor: .windowBackgroundColor)
        case .raised:
            return Color(nsColor: .controlBackgroundColor)
        case .sunken:
            return Color(nsColor: .textBackgroundColor)
        }
    }
}
