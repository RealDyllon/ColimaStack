//
//  ActionButtons.swift
//  ColimaStack
//
//  Primary and destructive action buttons. Primary is the filled
//  accent button (`.borderedProminent`); destructive is the same shape
//  in the critical status color. Both consume `DesignSystem.Radius.control`
//  and the standard macOS control padding.
//

import SwiftUI

public struct PrimaryButton: View {
    let title: String
    let symbol: String?
    let action: () -> Void

    @Environment(\.colorRole) private var colorRole

    public init(_ title: String, symbol: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(colorRole(.accentPrimary))
    }
}

public struct DestructiveButton: View {
    let title: String
    let symbol: String?
    let role: ButtonRole?
    let action: () -> Void

    @Environment(\.colorRole) private var colorRole

    public init(_ title: String, symbol: String? = nil, role: ButtonRole? = .destructive, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(colorRole(.statusCritical))
    }
}
