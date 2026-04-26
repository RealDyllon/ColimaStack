import AppKit
import SwiftUI

enum WorkspaceTone {
    case neutral
    case info
    case success
    case warning
    case critical

    var foregroundColor: Color {
        switch self {
        case .neutral: .secondary
        case .info: .blue
        case .success: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .neutral:
            Color(nsColor: .controlBackgroundColor)
        case .info:
            Color.blue.opacity(0.12)
        case .success:
            Color.green.opacity(0.12)
        case .warning:
            Color.orange.opacity(0.14)
        case .critical:
            Color.red.opacity(0.12)
        }
    }
}

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

struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String
    @ViewBuilder private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(title, systemImage: symbol)
                        .font(.headline)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SurfaceStateView<Actions: View>: View {
    let title: String
    let message: String
    let symbol: String
    let tone: WorkspaceTone
    @ViewBuilder private let actions: Actions

    init(
        title: String,
        message: String,
        symbol: String,
        tone: WorkspaceTone = .neutral,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.tone = tone
        self.actions = actions()
    }

    init(
        title: String,
        message: String,
        symbol: String,
        tone: WorkspaceTone = .neutral
    ) where Actions == EmptyView {
        self.init(title: title, message: message, symbol: symbol, tone: tone, actions: { EmptyView() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(tone.foregroundColor)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(tone.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatusBanner<Actions: View>: View {
    let title: String
    let message: String
    let symbol: String
    let tone: WorkspaceTone
    @ViewBuilder private let actions: Actions

    init(
        title: String,
        message: String,
        symbol: String,
        tone: WorkspaceTone,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.tone = tone
        self.actions = actions()
    }

    init(
        title: String,
        message: String,
        symbol: String,
        tone: WorkspaceTone
    ) where Actions == EmptyView {
        self.init(title: title, message: message, symbol: symbol, tone: tone, actions: { EmptyView() })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .foregroundStyle(tone.foregroundColor)
                .font(.headline)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)
            actions
        }
        .padding(14)
        .background(tone.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    var tone: WorkspaceTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(tone == .neutral ? .primary : tone.foregroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct KeyValueGrid: View {
    let rows: [(String, String)]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
            ForEach(rows.filter { !$0.0.isEmpty }, id: \.0) { key, value in
                GridRow {
                    Text(key)
                        .foregroundStyle(.secondary)
                    Text(value.isEmpty ? "Unavailable" : value)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contextMenu {
                            Button("Copy") {
                                copyToPasteboard(value)
                            }
                            .disabled(value.isEmpty)
                        }
                }
            }
        }
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

struct RecordList<Rows: View>: View {
    let columns: [String]
    @ViewBuilder private let rows: Rows

    init(columns: [String], @ViewBuilder rows: () -> Rows) {
        self.columns = columns
        self.rows = rows()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ForEach(columns, id: \.self) { column in
                    Text(column)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .underPageBackgroundColor))

            VStack(spacing: 0) {
                rows
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct RecordRow: View {
    let leading: String
    let secondary: String
    let tertiary: String
    let trailing: String
    var tone: WorkspaceTone = .neutral

    var body: some View {
        HStack(spacing: 16) {
            Text(leading)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(secondary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(tertiary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(trailing)
                .foregroundStyle(tone == .neutral ? .secondary : tone.foregroundColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 16)
        }
        .contextMenu {
            Button("Copy Row") {
                copyToPasteboard([leading, secondary, tertiary, trailing].filter { !$0.isEmpty }.joined(separator: "\t"))
            }
        }
    }
}

struct TerminalLogView: View {
    let text: String
    let minHeight: CGFloat

    init(text: String, minHeight: CGFloat = 180) {
        self.text = text
        self.minHeight = minHeight
    }

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "No output available." : text)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(12)
        }
        .frame(minHeight: minHeight, maxHeight: minHeight + 120)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

struct StatusDot: View {
    let state: ProfileState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .accessibilityLabel(state.label)
    }

    private var color: Color {
        switch state {
        case .running:
            .green
        case .stopped:
            .secondary
        case .degraded, .broken:
            .orange
        case .starting, .stopping:
            .blue
        case .unknown:
            .gray
        }
    }
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
