//
//  ToolbarActionButton.swift
//  ColimaStack
//
//  An icon-first toolbar button that respects the user's macOS
//  toolbar preference (icon only, icon + label, label only) and that
//  is the single source of truth for action affordances in the
//  toolbar, contextual action bars, and per-row action menus.
//

import SwiftUI

public struct ToolbarActionButton: View {
    let symbol: String
    let label: String?
    var role: ButtonRole? = nil
    var prominence: Prominence = .standard
    var isOn: Bool? = nil
    let action: () -> Void

    public enum Prominence {
        /// Standard bordered button.
        case standard
        /// Filled, accent-tinted — used for primary toolbar actions.
        case prominent
        /// Borderless — used for toggle-style toolbar items.
        case borderless
    }

    public init(
        symbol: String,
        label: String? = nil,
        role: ButtonRole? = nil,
        prominence: Prominence = .standard,
        isOn: Bool? = nil,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.label = label
        self.role = role
        self.prominence = prominence
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Group {
            switch prominence {
            case .standard:
                if let label, !label.isEmpty {
                    Button(role: role, action: action) {
                        Label(label, systemImage: symbol)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(role: role, action: action) {
                        Image(systemName: symbol)
                    }
                    .buttonStyle(.bordered)
                }
            case .prominent:
                if let label, !label.isEmpty {
                    Button(role: role, action: action) {
                        Label(label, systemImage: symbol)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(role: role, action: action) {
                        Image(systemName: symbol)
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .borderless:
                if let label, !label.isEmpty {
                    Button(role: role, action: action) {
                        Label(label, systemImage: symbol)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button(role: role, action: action) {
                        Image(systemName: symbol)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .tint(isOn == true ? .accentColor : nil)
    }
}
