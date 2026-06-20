//
//  TextStyle.swift
//  ColimaStack
//
//  Typography scale. Every title, subtitle, label, and value in the app
//  binds to one of these styles. The `display` style is reserved for
//  hero/marketing surfaces; detail screens use `title2` (22pt) as the
//  largest text.
//

import SwiftUI

extension DesignSystem {
    /// A semantic text style. Each case maps to a `Font` whose size and
    /// weight are tuned for a single role in the UI.
    public enum TextStyle {
        case display
        case title1
        case title2
        case title3
        case body
        case caption
        case code
        case mono

        /// The `Font` to apply. `body`, `caption`, and `code` participate
        /// in Dynamic Type by using the system semantic styles where
        /// possible; `display` and `title*` are fixed sizes to keep
        /// card and toolbar layouts stable.
        public var font: Font {
            switch self {
            case .display:
                return .system(size: 28, weight: .bold, design: .default)
            case .title1:
                return .system(size: 24, weight: .semibold, design: .default)
            case .title2:
                return .system(size: 22, weight: .semibold, design: .default)
            case .title3:
                return .system(size: 17, weight: .semibold, design: .default)
            case .body:
                return .body
            case .caption:
                return .caption
            case .code:
                return .system(.body, design: .monospaced)
            case .mono:
                return .system(.caption, design: .monospaced)
            }
        }

        /// A `Text` view already styled with this token. Prefer this over
        /// calling `.font(.system(...))` directly in screen code.
        public func text<S: StringProtocol>(_ content: S) -> Text {
            Text(content).font(font)
        }
    }
}

// MARK: - View modifiers

public extension View {
    /// Apply a semantic `DesignSystem.TextStyle` to a view.
    func textStyle(_ style: DesignSystem.TextStyle) -> some View {
        font(style.font)
    }
}
