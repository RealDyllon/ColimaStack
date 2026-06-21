//
//  Icon.swift
//  ColimaStack
//
//  The single source of truth for SF Symbols. Every screen consumes
//  icons via `Icon.brand`, `Icon.runtime.*`, `Icon.profile.*`, etc.
//  Raw `Image(systemName:)` literals SHALL NOT appear in screen code
//  outside of this file.
//
//  One symbol per concept:
//    * `Icon.brand` — the ColimaStack brand mark (used in sidebar
//      header, menu bar, about screen). Never used for a profile or a
//      runtime.
//    * `Icon.runtime.*` — runtime identification (docker, containerd,
//      apple). Distinct from `Icon.brand` and `Icon.profile.*`.
//    * `Icon.profile.*` — profile state (running, stopped, starting,
//      stopping, degraded, broken, unknown). Drives the StateDot and
//      the menu bar label.
//    * `Icon.kubernetes.*` — Kubernetes section and enabled/disabled
//      state. The hexagon.
//    * `Icon.action.*` — lifecycle actions (start, stop, restart,
//      delete, refresh, edit, reveal, copy, open, inspect, logs).
//    * `Icon.section.*` — sidebar section headers.
//    * `Icon.empty.*` — empty-state illustrations.
//

import SwiftUI

public enum Icon {}

public extension Icon {
    /// The brand mark. Uses the custom `BrandMark` asset if present;
    /// otherwise falls back to the SF Symbol `shippingbox.fill`. The
    /// brand mark is reserved for app-level surfaces (sidebar header,
    /// menu bar, about screen).
    static var brand: IconView {
        IconView(symbolName: "shippingbox.fill", size: .control)
    }

    /// The brand mark at hero size (48pt), used in onboarding and the
    /// about screen.
    static var brandHero: IconView {
        IconView(symbolName: "shippingbox.fill", size: .hero)
    }
}

public extension Icon {
    enum Runtime {
        public static let docker = IconView(symbolName: "shippingbox.fill", size: .row)
        public static let containerd = IconView(symbolName: "cube.box.fill", size: .row)
        public static let apple = IconView(symbolName: "cube.transparent.fill", size: .row)
    }
}

public extension Icon {
    enum Profile {
        public static let running = IconView(symbolName: "play.circle.fill", size: .row)
        public static let stopped = IconView(symbolName: "stop.circle", size: .row)
        public static let starting = IconView(symbolName: "arrow.triangle.2.circlepath", size: .row)
        public static let stopping = IconView(symbolName: "arrow.triangle.2.circlepath", size: .row)
        public static let degraded = IconView(symbolName: "exclamationmark.triangle.fill", size: .row)
        public static let broken = IconView(symbolName: "xmark.octagon.fill", size: .row)
        public static let unknown = IconView(symbolName: "questionmark.circle", size: .row)

        /// The icon for a profile's current state, derived from a
        /// `ProfileState`. This is the canonical mapping; the menu
        /// bar label and the sidebar profile row both consume it.
        static func forState(_ state: ProfileState) -> IconView {
            switch state {
            case .running: return running
            case .stopped: return stopped
            case .starting: return starting
            case .stopping: return stopping
            case .degraded: return degraded
            case .broken: return broken
            case .unknown: return unknown
            }
        }

        /// Color tint for a given profile state. The sidebar roster
        /// and the menu bar label apply this so state changes are
        /// legible at a glance without shouting in saturated color.
        static func tint(for state: ProfileState) -> Color {
            switch state {
            case .running: return .green
            case .starting, .stopping: return .blue
            case .stopped: return .secondary
            case .degraded: return .yellow
            case .broken: return .red
            case .unknown: return .secondary
            }
        }
    }
}

public extension Icon {
    enum Kubernetes {
        public static let section = IconView(symbolName: "hexagon", size: .row)
        public static let enabled = IconView(symbolName: "hexagon.fill", size: .row)
        public static let disabled = IconView(symbolName: "hexagon", size: .row)
        public static let cluster = IconView(symbolName: "server.rack", size: .row)
        public static let workloads = IconView(symbolName: "square.3.layers.3d", size: .row)
        public static let services = IconView(symbolName: "point.3.connected.trianglepath.dotted", size: .row)
    }
}

public extension Icon {
    enum Action {
        public static let start = IconView(symbolName: "play.fill", size: .control)
        public static let stop = IconView(symbolName: "stop.fill", size: .control)
        public static let restart = IconView(symbolName: "arrow.triangle.2.circlepath", size: .control)
        public static let delete = IconView(symbolName: "trash", size: .control)
        public static let refresh = IconView(symbolName: "arrow.clockwise", size: .control)
        public static let edit = IconView(symbolName: "slider.horizontal.3", size: .control)
        public static let reveal = IconView(symbolName: "folder", size: .control)
        public static let copy = IconView(symbolName: "doc.on.doc", size: .control)
        public static let open = IconView(symbolName: "macwindow", size: .control)
        public static let inspect = IconView(symbolName: "doc.text.magnifyingglass", size: .control)
        public static let logs = IconView(symbolName: "doc.plaintext", size: .control)
        public static let terminal = IconView(symbolName: "terminal", size: .control)
        public static let settings = IconView(symbolName: "gearshape", size: .control)
        public static let about = IconView(symbolName: "info.circle", size: .control)
        public static let quit = IconView(symbolName: "power", size: .control)
        public static let add = IconView(symbolName: "plus", size: .control)
        public static let remove = IconView(symbolName: "minus.circle", size: .control)
        public static let search = IconView(symbolName: "magnifyingglass", size: .control)
        public static let diagnostics = IconView(symbolName: "stethoscope", size: .control)
        public static let wrench = IconView(symbolName: "wrench.and.screwdriver", size: .control)
        public static let health = IconView(symbolName: "heart.text.square", size: .control)
        public static let autoRefresh = IconView(symbolName: "clock.arrow.trianglehead.counterclockwise.rotate.90", size: .control)
    }
}

public extension Icon {
    enum Section {
        public static let workspace = IconView(symbolName: "square.grid.2x2", size: .row)
        public static let runtime = IconView(symbolName: "shippingbox", size: .row)
        public static let kubernetes = IconView(symbolName: "hexagon", size: .row)
        public static let support = IconView(symbolName: "questionmark.bubble", size: .row)
        public static let profiles = IconView(symbolName: "person.2", size: .row)
    }
}

public extension Icon {
    enum Empty {
        public static let noResults = IconView(symbolName: "magnifyingglass", size: .hero)
        public static let noData = IconView(symbolName: "tray", size: .hero)
        public static let error = IconView(symbolName: "exclamationmark.arrow.triangle.2.circlepath", size: .hero)
        public static let unavailable = IconView(symbolName: "shippingbox.circle", size: .hero)
        public static let disabled = IconView(symbolName: "hexagon", size: .hero)
    }
}

// MARK: - IconView

/// A pre-sized `Image` view produced by the `Icon` namespace. Each
/// access on the namespace returns an `IconView` so the call site can
/// use `Icon.brand` directly in a view hierarchy.
public struct IconView: View {
    public let symbolName: String
    let size: DesignSystem.IconSizeKind

    public init(symbolName: String, size: DesignSystem.IconSizeKind) {
        self.symbolName = symbolName
        self.size = size
    }

    public var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size.points, weight: .medium))
            .imageScale(size.imageScale)
    }
}

public extension DesignSystem {
    enum IconSizeKind {
        case control
        case row
        case hero

        var points: CGFloat {
            switch self {
            case .control: return IconSize.control
            case .row: return IconSize.row
            case .hero: return IconSize.hero
            }
        }

        var imageScale: Image.Scale {
            switch self {
            case .control: return .small
            case .row: return .medium
            case .hero: return .large
            }
        }
    }
}
