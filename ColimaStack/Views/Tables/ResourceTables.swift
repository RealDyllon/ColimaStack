//
//  ResourceTables.swift
//  ColimaStack
//
//  Table-based resource views, density, column customization, and the
//  contextual action bar. Implements the data-tables capability from
//  the apple-design-award-ui change.
//

import AppKit
import SwiftUI

// MARK: - Table density

/// How compact a table is rendered. Stored on `AppState` so the user's
/// choice persists across launches.
public enum TableDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard
    case compact

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .standard: return "Standard"
        case .compact: return "Compact"
        }
    }

    public var rowVerticalPadding: CGFloat {
        switch self {
        case .standard: return 8
        case .compact: return 3
        }
    }

    public var font: Font {
        switch self {
        case .standard: return .body
        case .compact: return .subheadline
        }
    }
}

/// A key identifying a resource type for column-customization storage.
public enum ResourceTableKind: String, Codable, Hashable, Sendable, CaseIterable {
    case containers
    case images
    case runtimeVolumes
    case runtimeNetworks
    case kubernetesPods
    case kubernetesDeployments
    case kubernetesServices

    public var displayName: String {
        switch self {
        case .containers: return "Containers"
        case .images: return "Images"
        case .runtimeVolumes: return "Volumes"
        case .runtimeNetworks: return "Networks"
        case .kubernetesPods: return "Pods"
        case .kubernetesDeployments: return "Deployments"
        case .kubernetesServices: return "Services"
        }
    }
}

// MARK: - Resource row actions

/// Common row affordances (context menu + selection). Each table view
/// composes its columns and applies these modifiers per-row.
struct ResourceRowActions: ViewModifier {
    let density: TableDensity
    @ViewBuilder let contextMenuItems: () -> AnyView

    func body(content: Content) -> some View {
        content
            .padding(.vertical, density.rowVerticalPadding)
            .contextMenu { contextMenuItems() }
    }
}

extension View {
    /// Standard resource-row presentation: row padding driven by
    /// density, context menu attached.
    func resourceRowStyle(density: TableDensity, @ViewBuilder contextMenu: @escaping () -> AnyView) -> some View {
        modifier(ResourceRowActions(density: density, contextMenuItems: contextMenu))
    }
}

// MARK: - TableContextualActionBar

/// The contextual action bar that appears when the user has selected one
/// or more rows in a table.
struct TableContextualActionBar: View {
    let count: Int
    let primaryLabel: String?
    let onDismiss: () -> Void
    @ViewBuilder let actions: (Int) -> AnyView

    var body: some View {
        if count > 0 {
            HStack(spacing: 10) {
                Text("\(count) selected")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                actions(count)
                if let primaryLabel, count > 0 {
                    Button(primaryLabel) {
                        // Provided via the actions closure.
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Dismiss selection")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .contain)
        }
    }
}

// MARK: - TableColumnCustomization

/// Persists per-resource column visibility + order in `AppState`. Stored
/// as a single dictionary keyed by `ResourceTableKind`.
struct TableColumnCustomization {
    /// Per-kind ordered list of column identifiers. Columns that
    /// appear in the schema but are missing from the list are appended
    /// at the end with default visibility.
    var order: [ResourceTableKind: [String]]
    /// Per-kind hidden columns.
    var hidden: [ResourceTableKind: Set<String>]

    init() {
        self.order = [:]
        self.hidden = [:]
    }

    func order(for kind: ResourceTableKind, default fallback: [String]) -> [String] {
        order[kind] ?? fallback
    }

    mutating func setOrder(_ ids: [String], for kind: ResourceTableKind) {
        order[kind] = ids
    }

    func isHidden(_ id: String, for kind: ResourceTableKind) -> Bool {
        hidden[kind]?.contains(id) ?? false
    }

    mutating func setHidden(_ id: String, hidden: Bool, for kind: ResourceTableKind) {
        var current = self.hidden[kind] ?? []
        if hidden {
            current.insert(id)
        } else {
            current.remove(id)
        }
        self.hidden[kind] = current
    }
}

// MARK: - Copy helpers

/// Tabs-separated copy for "Copy Row" actions.
func tableRowCopyValue(_ values: [String]) -> String {
    values.filter { !$0.isEmpty }.joined(separator: "\t")
}

func tableRowCopyToPasteboard(_ values: [String]) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(tableRowCopyValue(values), forType: .string)
}

// MARK: - Table cell primitives

/// A monospaced cell for IDs, hashes, ports, and other long strings.
struct TableMonocell: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

/// A pill cell used for the "state" column.
struct TableStateCell: View {
    let text: String
    let tone: WorkspaceTone

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(tone.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tone.foregroundColor.opacity(0.12))
            .clipShape(Capsule())
    }
}
