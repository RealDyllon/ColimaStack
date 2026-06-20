//
//  DesignSystem.swift
//  ColimaStack
//
//  The design-system namespace. Every screen in ColimaStack consumes
//  tokens through this namespace. Raw Color/Font/CGFloat literals
//  SHALL NOT appear in screen code outside of this folder.
//

import SwiftUI

/// The single entry point for design tokens and shared primitives.
///
/// The namespace is split into:
///   * `Tokens` — value types (TextStyle, ColorRole, Spacing, Radius, Elevation, Motion).
///   * `Primitives` — view components built from those tokens.
///
/// Each token has a single declaration; each primitive has a single
/// implementation. When a screen needs a value, it asks `DesignSystem.*`.
public enum DesignSystem {}

extension DesignSystem {
    /// Icon-size tokens used by the `Icon` namespace and the toolbar/row/hero
    /// accessors. Sizes are point values suitable for `.font(.system(size:))`
    /// and `.frame(width:height:)`.
    public enum IconSize {
        public static let control: CGFloat = 16
        public static let row: CGFloat = 20
        public static let hero: CGFloat = 48
    }
}
