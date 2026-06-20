//
//  Spacing.swift
//  ColimaStack
//
//  Four-point spacing scale. Card padding is `md` (16pt); section
//  spacing inside a `ScrollView` is `lg` (24pt). Off-grid values SHALL
//  NOT appear in screen code outside of `DesignSystem/`.
//

import SwiftUI

extension DesignSystem {
    /// Spacing tokens. Each case is a `CGFloat` in points. The numeric
    /// values are exposed for layout (`.padding(.all, Spacing.md)`); the
    /// `CGFloat` conformance is provided for math (`Spacing.md * 2`).
    public enum Spacing: CGFloat {
        case xs = 4
        case sm = 8
        case md = 16
        case lg = 24
        case xl = 32
        case xxl = 48
    }
}

extension DesignSystem {
    /// Corner-radius tokens. `control` is for buttons, inputs, and
    /// toggles; `card` is for `SectionCard` and `MetricTile`; `pill` is
    /// for fully-rounded shapes.
    public enum Radius: CGFloat {
        case control = 6
        case card = 12
        case pill = 999
    }
}
