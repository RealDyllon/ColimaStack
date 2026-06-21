//
//  ContainerDetailSheets.swift
//  ColimaStack
//
//  Container Inspect and Logs sheets. Both are presented in
//  response to notifications posted by the table row context
//  menu and the contextual action bar.
//

import AppKit
import SwiftUI

// MARK: - Inspect sheet

struct ContainerInspectSheet: View {
    let containerID: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var sections: [InspectSection] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            search
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if sections.isEmpty {
                        SurfaceStateView(
                            title: "No inspect data yet",
                            message: "Select a container in the Containers view to inspect.",
                            symbol: "doc.text.magnifyingglass",
                            tone: .neutral
                        )
                    } else {
                        ForEach(filteredSections) { section in
                            SectionCard(
                                title: section.title,
                                subtitle: section.subtitle,
                                symbol: section.symbol
                            ) {
                                KeyValueGrid(rows: section.rows)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 720, minHeight: 600)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Inspect container")
                    .font(.system(size: 17, weight: .semibold))
                Text(containerID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var search: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Filter inspect fields…", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var filteredSections: [InspectSection] {
        guard !searchText.isEmpty else { return sections }
        let needle = searchText.lowercased()
        return sections.compactMap { section in
            let filteredRows = section.rows.filter { row in
                row.0.lowercased().contains(needle) || row.1.lowercased().contains(needle)
            }
            guard !filteredRows.isEmpty else { return nil }
            return InspectSection(title: section.title, subtitle: section.subtitle, symbol: section.symbol, rows: filteredRows)
        }
    }
}

struct InspectSection: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let rows: [(String, String)]
}

// MARK: - Logs sheet

struct ContainerLogsSheet: View {
    let containerID: String
    @StateObject private var buffer: LogStreamBuffer = LogStreamBuffer()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TerminalLogView(buffer: buffer)
        }
        .frame(minWidth: 720, minHeight: 540)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Container logs")
                    .font(.system(size: 17, weight: .semibold))
                Text(containerID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Delete confirm dialog

struct ContainerDeleteConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let containerNames: [String]
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                deleteTitle,
                isPresented: $isPresented
            ) {
                Button("Delete \(countText)", role: .destructive) {
                    onConfirm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteMessage)
            }
    }

    private var countText: String {
        switch containerNames.count {
        case 1: return containerNames[0]
        case 2: return "\(containerNames[0]) and \(containerNames[1])"
        default: return "\(containerNames.count) containers"
        }
    }

    private var deleteTitle: String {
        containerNames.count == 1
            ? "Delete container \(containerNames[0])?"
            : "Delete \(containerNames.count) containers?"
    }

    private var deleteMessage: String {
        if containerNames.count == 1 {
            return "This permanently removes the container named \(containerNames[0]). This cannot be undone."
        }
        return "This permanently removes \(containerNames.count) containers: \(containerNames.joined(separator: ", ")). This cannot be undone."
    }
}

extension View {
    /// Present a destructive delete confirmation alert.
    func containerDeleteConfirmation(isPresented: Binding<Bool>, names: [String], onConfirm: @escaping () -> Void) -> some View {
        modifier(ContainerDeleteConfirmation(isPresented: isPresented, containerNames: names, onConfirm: onConfirm))
    }
}
