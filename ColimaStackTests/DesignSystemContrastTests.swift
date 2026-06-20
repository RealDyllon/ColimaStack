//
//  DesignSystemContrastTests.swift
//  ColimaStack
//
//  Asserts that every (text role, surface role) pair used in the app
//  passes WCAG 2.1 AA contrast in both light and dark mode. Failing
//  pairs fail the build so a regression in the design system is
//  caught before it reaches a screen.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import ColimaStack

@MainActor
struct DesignSystemContrastTests {
    /// The pairs that we expect to be valid. Add a new pair here only
    /// after the design has decided that the combination is acceptable.
    private let textOnSurfacePairs: [(DesignSystem.ColorRole, DesignSystem.ColorRole)] = [
        (.textPrimary, .surfaceCanvas),
        (.textPrimary, .surfaceRaised),
        (.textPrimary, .surfaceSunken),
        (.textSecondary, .surfaceCanvas),
        (.textSecondary, .surfaceRaised),
        (.textSecondary, .surfaceSunken),
        (.textTertiary, .surfaceCanvas),
        (.textTertiary, .surfaceRaised),
        (.textTertiary, .surfaceSunken)
    ]

    @Test func textOnSurfacePairsMeetWCAGAAInLightMode() {
        for (text, surface) in textOnSurfacePairs {
            let resolvedText = text.resolve(colorScheme: .light)
            let resolvedSurface = surface.resolve(colorScheme: .light)
            let ratio = contrastRatio(foreground: resolvedText, background: resolvedSurface)
            #expect(ratio >= 4.5, "Text \(text) on \(surface) failed light-mode contrast: \(ratio)")
        }
    }

    @Test func textOnSurfacePairsMeetWCAGAAInDarkMode() {
        for (text, surface) in textOnSurfacePairs {
            let resolvedText = text.resolve(colorScheme: .dark)
            let resolvedSurface = surface.resolve(colorScheme: .dark)
            let ratio = contrastRatio(foreground: resolvedText, background: resolvedSurface)
            #expect(ratio >= 4.5, "Text \(text) on \(surface) failed dark-mode contrast: \(ratio)")
        }
    }

    // MARK: - Helpers

    /// Compute the WCAG 2.1 contrast ratio between two `Color` values.
    private func contrastRatio(foreground: Color, background: Color) -> Double {
        let fg = relativeLuminance(foreground)
        let bg = relativeLuminance(background)
        let lighter = max(fg, bg)
        let darker = min(fg, bg)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: Color) -> Double {
        // Resolve SwiftUI Color to NSColor for both appearances and pick
        // the one matching the system appearance. The contrast audit
        // runs against both light and dark mode; here we use a
        // neutral conversion for the test fixture.
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.black
        let r = pow(channel(nsColor.redComponent), 2.2)
        let g = pow(channel(nsColor.greenComponent), 2.2)
        let b = pow(channel(nsColor.blueComponent), 2.2)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private func channel(_ value: CGFloat) -> Double {
        let v = Double(value)
        return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
}
