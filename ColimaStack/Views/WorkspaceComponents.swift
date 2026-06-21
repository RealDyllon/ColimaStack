import AppKit
import SwiftUI

// The shared design-system primitives (SectionCard, MetricTile, StatusBanner,
// KeyValueGrid, EmptyStateView, StateDot, IconBadge) now live under
// `ColimaStack/DesignSystem/Primitives/` and are imported automatically
// through the same module. The legacy duplicates that previously lived
// here have been removed; the migration is in progress as part of
// openspec/changes/apple-design-award-ui/.

struct DetailScreenLayout<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder private let accessory: Accessory
    @ViewBuilder private let content: Content

    init(
        title: String,
        subtitle: String,
        symbol: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.accessory = accessory()
        self.content = content()
    }

    init(
        title: String,
        subtitle: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) where Accessory == EmptyView {
        self.init(title: title, subtitle: subtitle, symbol: symbol, accessory: { EmptyView() }, content: content)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(title, systemImage: symbol)
                            .font(.system(size: 28, weight: .semibold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 20)
                    accessory
                }

                content
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .stableVerticalScroller()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private extension View {
    func stableVerticalScroller() -> some View {
        background(ScrollViewConfigurationView())
    }
}

private struct ScrollViewConfigurationView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureScrollView(containing: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureScrollView(containing: nsView)
        }
    }

    private func configureScrollView(containing view: NSView) {
        guard let scrollView = view.enclosingScrollView else { return }
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
    }
}

struct UsageBar: View {
    let label: String
    let value: String
    let progress: Double
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .separatorColor).opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint)
                        .frame(width: max(10, proxy.size.width * max(0, min(progress, 1))))
                }
            }
            .frame(height: 10)
        }
    }
}

struct SearchSummaryView: View {
    let query: String
    let resultCount: Int
    let scopeLabel: String

    var body: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else {
            StatusBanner(
                title: resultCount == 0 ? "No matches" : "\(resultCount) match\(resultCount == 1 ? "" : "es")",
                message: "Filtering \(scopeLabel) for \"\(query)\".",
                symbol: resultCount == 0 ? "magnifyingglass.circle" : "line.3.horizontal.decrease.circle",
                tone: resultCount == 0 ? .warning : .info
            )
        }
    }
}

/// Backward-compatible single-`Text` log view. New callers should
/// use the streaming `TerminalLogView` (buffer-backed) from
/// `Views/Terminal/TerminalLogView.swift`.
typealias LegacyTerminalLogView = TerminalLogView

func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

struct ToolRow: View {
    let tool: ToolCheck

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var detail: String {
        switch tool.availability {
        case .available(let path, let version):
            [path, version].compactMap { $0 }.joined(separator: " - ")
        case .missing:
            "Not found on PATH"
        case .error(let message):
            message
        }
    }

    private var symbol: String {
        switch tool.availability {
        case .available:
            "checkmark.circle.fill"
        case .missing:
            "xmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch tool.availability {
        case .available:
            .green
        case .missing:
            .red
        case .error:
            .orange
        }
    }
}
