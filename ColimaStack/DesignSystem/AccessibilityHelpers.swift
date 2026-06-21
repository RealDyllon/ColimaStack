//
//  AccessibilityHelpers.swift
//  ColimaStack
//
//  Centralized accessibility affordances: combined state-dot +
//  label groups, high-contrast token overrides, dynamic-type
//  reflow, and a Help > Keyboard Shortcuts menu. Implements the
//  accessibility capability from the apple-design-award-ui change.
//

import AppKit
import Combine
import SwiftUI

// MARK: - Combined element

/// Combine a state indicator + label into a single VoiceOver
/// element so the screen reader announces "State: running" once
/// instead of "running, dot" or two separate hits.
struct CombinedStateLabel: View {
    let state: String
    let tone: WorkspaceTone
    let prefix: String

    var body: some View {
        HStack(spacing: 4) {
            StateDot(tone: tone)
            Text("\(prefix): \(state)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prefix): \(state)")
    }
}

// MARK: - High-contrast token overrides

/// Returns token values for high-contrast mode. The system provides
/// this via the `\.colorSchemeContrast` environment value; this is
/// the indirection point so view code can do
/// `HighContrastTokens.borderOpacity` instead of branching on
/// `\.colorSchemeContrast` everywhere.
public enum HighContrastTokens {
    public static var borderOpacity: Double {
        if isHighContrast() { return 0.24 }
        return 0.08
    }

    public static var textContrast: Double {
        if isHighContrast() { return 1.0 }
        return 0.9
    }

    private static func isHighContrast() -> Bool {
        let appearance = NSApplication.shared.effectiveAppearance
        return appearance.bestMatch(from: [.accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua, .vibrantDark, .aqua]) == .accessibilityHighContrastAqua
    }
}

// MARK: - Force high contrast

/// User-controllable toggle in Settings > General that forces
/// high-contrast tokens regardless of the system setting.
public final class HighContrastPreference: ObservableObject {
    public static let shared = HighContrastPreference()
    @Published public var forced: Bool = false {
        didSet {
            UserDefaults.standard.set(forced, forKey: "accessibility.forceHighContrast")
            applyToAppearance()
        }
    }

    public init() {
        self.forced = UserDefaults.standard.bool(forKey: "accessibility.forceHighContrast")
        applyToAppearance()
    }

    private func applyToAppearance() {
        NSApplication.shared.appearance = forced
            ? NSAppearance(named: .accessibilityHighContrastAqua)
            : nil
    }
}

// MARK: - Dynamic type

/// Reflows metric tiles and card rows vertically when the dynamic
/// type size exceeds a threshold. The wrapper uses
/// `@Environment(\.dynamicTypeSize)` to detect the bump.
struct DynamicTypeReflow<Content: View>: View {
    let threshold: DynamicTypeSize
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize >= threshold {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        } else {
            content()
        }
    }
}

extension View {
    /// Reflow vertically at a large dynamic type size.
    func dynamicTypeReflow(threshold: DynamicTypeSize = .accessibility1) -> some View {
        DynamicTypeReflow(threshold: threshold) { self }
    }
}

// MARK: - Help > Keyboard Shortcuts

/// Keyboard shortcuts menu. Lists every shortcut grouped by surface.
struct KeyboardShortcutsMenu: View {
    @Environment(\.openSettings) private var openSettings

    struct Entry: Identifiable, Hashable {
        let id = UUID()
        let shortcut: String
        let description: String
    }

    struct Group: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let entries: [Entry]
    }

    private let groups: [Group] = [
        Group(title: "General", entries: [
            Entry(shortcut: "⌘R", description: "Refresh runtime and Kubernetes data"),
            Entry(shortcut: "⌘F", description: "Focus the search field"),
            Entry(shortcut: "⌘,", description: "Open Settings"),
            Entry(shortcut: "⌘Q", description: "Quit ColimaStack")
        ]),
        Group(title: "Profile", entries: [
            Entry(shortcut: "⌘N", description: "Create a new profile"),
            Entry(shortcut: "⌘E", description: "Edit the selected profile"),
            Entry(shortcut: "⌘.", description: "Cancel the profile editor")
        ]),
        Group(title: "Settings", entries: [
            Entry(shortcut: "⌘1", description: "Show General settings"),
            Entry(shortcut: "⌘2", description: "Show Kubernetes settings"),
            Entry(shortcut: "⌘3", description: "Show Networking settings"),
            Entry(shortcut: "⌘4", description: "Show Integrations settings"),
            Entry(shortcut: "⌘5", description: "Show Advanced settings")
        ]),
        Group(title: "Container lifecycle", entries: [
            Entry(shortcut: "⌘⇧S", description: "Start selected containers"),
            Entry(shortcut: "⌘⇧T", description: "Stop selected containers"),
            Entry(shortcut: "⌘⇧R", description: "Restart selected containers"),
            Entry(shortcut: "⌫", description: "Delete selected containers")
        ])
    ]

    var body: some View {
        ForEach(groups) { group in
            Section(group.title) {
                ForEach(group.entries) { entry in
                    HStack {
                        Text(entry.description)
                        Spacer()
                        Text(entry.shortcut)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Accessibility audit helper

/// A simple grep-friendly tag that view code can attach to
/// interactive controls to assert that the audit test (Group 11.9)
/// catches any missing label.
struct AccessibilityAudited: ViewModifier {
    let label: String?
    let hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
    }
}

extension View {
    /// Tag a control with its accessibility label and hint.
    /// The audit test walks the view tree and asserts that every
    /// interactive control has a non-empty label.
    func accessibilityAudited(label: String?, hint: String? = nil) -> some View {
        modifier(AccessibilityAudited(label: label, hint: hint))
    }
}
