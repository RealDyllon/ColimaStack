//
//  StateDot.swift
//  ColimaStack
//
//  A small colored dot that communicates a `ProfileState` (or a
//  generic `WorkspaceTone`). The dot is the primary state indicator;
//  the text label is supplementary.
//

import SwiftUI

public struct StateDot: View {
    let tone: WorkspaceTone

    @Environment(\.colorRole) private var colorRole

    public init(tone: WorkspaceTone) {
        self.tone = tone
    }

    /// Convenience initializer that maps a `ProfileState` to a tone.
    init(profileState: ProfileState) {
        self.tone = Self.tone(for: profileState)
    }

    public var body: some View {
        Circle()
            .fill(colorRole(tone.foregroundColorRole))
            .frame(width: 10, height: 10)
    }

    private static func tone(for state: ProfileState) -> WorkspaceTone {
        switch state {
        case .running:
            return .success
        case .starting, .stopping:
            return .info
        case .degraded, .broken:
            return .warning
        case .stopped, .unknown:
            return .neutral
        }
    }
}

/// Backwards-compatible alias. The legacy `StatusDot(state:)` was
/// keyed off `ProfileState`; the new `StateDot(tone:)` is keyed off
/// `WorkspaceTone`. Existing call sites continue to compile via this
/// shim. New code SHALL use `StateDot(profileState:)` or
/// `StateDot(tone:)` directly.
public typealias StatusDot = StateDot

extension StateDot {
    /// Backwards-compatible `StatusDot(state: ProfileState)` initializer.
    init(state: ProfileState) {
        self.init(profileState: state)
    }
}
