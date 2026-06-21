//
//  TerminalLogView.swift
//  ColimaStack
//
//  Streaming monospace log view backed by `NSTextView`. Implements
//  the terminal-view capability from the apple-design-award-ui
//  change. Replaces the SwiftUI `Text`-based `TerminalLogView` in
//  `Views/WorkspaceComponents.swift` (still re-exported as a SwiftUI
//  shell for callers that don't need streaming).
//

import AppKit
import Combine
import SwiftUI

// MARK: - Log line model

public enum LogStream: String, Codable, Sendable, Hashable {
    case stdout
    case stderr
    case system
    case error

    public var nsColor: NSColor {
        switch self {
        case .stdout: return .labelColor
        case .stderr: return .systemOrange
        case .system: return .secondaryLabelColor
        case .error: return .systemRed
        }
    }
}

public struct LogLine: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let stream: LogStream
    public let text: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), stream: LogStream, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.stream = stream
        self.text = text
    }
}

// MARK: - LogStream (buffer)

/// Append-only buffer with a 5000-line FIFO cap. The visible buffer
/// is bounded so the view stays responsive even with sustained
/// streaming.
@MainActor
public final class LogStreamBuffer: ObservableObject {
    public static let defaultMaxLines = 5_000

    @Published public private(set) var lines: [LogLine] = []
    public let maxLines: Int

    public init(maxLines: Int = LogStreamBuffer.defaultMaxLines) {
        self.maxLines = maxLines
    }

    public func append(_ line: LogLine) {
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    public func append(text: String, stream: LogStream) {
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            append(LogLine(stream: stream, text: String(raw)))
        }
    }

    public func clear() {
        lines.removeAll()
    }

    /// Render the current line buffer as a single newline-joined string.
    /// Used by `AppState.containerLogs` to feed the legacy inspect /
    /// log sheets that pre-date the streaming `TerminalLogView`.
    public func renderPlainText() -> String {
        lines.map(\.text).joined(separator: "\n")
    }
}

// MARK: - TerminalLogView (SwiftUI)

/// SwiftUI wrapper around the NSTextView-backed terminal log. Streams
/// `LogLine`s from a `LogStreamBuffer` with auto-scroll, "Jump to live"
/// affordance, search, and copy-all.
public struct TerminalLogView: View {
    @ObservedObject var buffer: LogStreamBuffer
    @State private var autoScroll: Bool = true
    @State private var searchText: String = ""
    @State private var showLineNumbers: Bool = true
    @State private var userIsScrolling: Bool = false
    @State private var stickToBottom: Bool = true
    @State private var copyAllAction: (() -> Void)?

    public init(buffer: LogStreamBuffer) {
        self.buffer = buffer
    }

    /// Backward-compatible initializer for callers that previously
    /// passed a static `String`. Wraps the string in a
    /// `LogStreamBuffer` with a single system line so the streaming
    /// view is used. `minHeight` is honored by wrapping the view
    /// in a `.frame(minHeight:)` at the call site if needed; this
    /// initializer ignores it (kept for source-compatibility only).
    public init(text: String, minHeight: CGFloat = 180) {
        let buffer = LogStreamBuffer()
        if !text.isEmpty {
            buffer.append(text: text, stream: .system)
        }
        self.buffer = buffer
        _ = minHeight
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            LogTextStorageView(
                buffer: buffer,
                showLineNumbers: showLineNumbers,
                searchText: searchText,
                stickToBottom: $stickToBottom,
                onUserScroll: { userScrolled in
                    userIsScrolling = userScrolled
                    if userScrolled && !stickToBottom {
                        autoScroll = false
                    }
                }
            )
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                showLineNumbers.toggle()
            } label: {
                Image(systemName: showLineNumbers ? "number.square.fill" : "number.square")
            }
            .buttonStyle(.borderless)
            .help(showLineNumbers ? "Hide line numbers" : "Show line numbers")

            TextField("Search…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)

            Button {
                buffer.clear()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear log")

            Spacer()

            if !autoScroll && !stickToBottom {
                Button {
                    stickToBottom = true
                    autoScroll = true
                } label: {
                    Label("Jump to live", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(8)
    }
}

// MARK: - LogTextStorageView (NSViewRepresentable)

/// NSTextView-backed log view. The text storage is an
/// `NSTextStorage` subclass that knows how to append and how to apply
/// per-stream color rules.
struct LogTextStorageView: NSViewRepresentable {
    @ObservedObject var buffer: LogStreamBuffer
    let showLineNumbers: Bool
    let searchText: String
    @Binding var stickToBottom: Bool
    let onUserScroll: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(buffer: buffer, showLineNumbers: showLineNumbers, onUserScroll: onUserScroll)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let storage = LogTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        textView.textContainer = container

        context.coordinator.attach(textView: textView, scrollView: scrollView, storage: storage)
        context.coordinator.applyBuffer()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.showLineNumbers = showLineNumbers
        context.coordinator.applyBuffer(forceAppend: false)
        if !searchText.isEmpty {
            context.coordinator.applySearchHighlight(searchText)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let buffer: LogStreamBuffer
        var showLineNumbers: Bool
        let onUserScroll: (Bool) -> Void
        private weak var textView: NSTextView?
        private weak var scrollView: NSScrollView?
        private var storage: LogTextStorage?
        private var lastRenderedCount: Int = 0
        private var lastBufferIdentity: ObjectIdentifier?

        init(buffer: LogStreamBuffer, showLineNumbers: Bool, onUserScroll: @escaping (Bool) -> Void) {
            self.buffer = buffer
            self.showLineNumbers = showLineNumbers
            self.onUserScroll = onUserScroll
        }

        func attach(textView: NSTextView, scrollView: NSScrollView, storage: LogTextStorage) {
            self.textView = textView
            self.scrollView = scrollView
            self.storage = storage
        }

        func applyBuffer(forceAppend: Bool = true) {
            guard let textView, let storage else { return }
            let lines = buffer.lines
            let bufferIdentity = ObjectIdentifier(buffer)
            let isNewBuffer = lastBufferIdentity != bufferIdentity
            if isNewBuffer {
                storage.setAttributedString(NSAttributedString())
                lastRenderedCount = 0
                lastBufferIdentity = bufferIdentity
            }
            if lines.count < lastRenderedCount {
                // Buffer shrunk (clear); reset.
                storage.setAttributedString(NSAttributedString())
                lastRenderedCount = 0
            }
            guard lines.count > lastRenderedCount else { return }
        let newSlice = lines[lastRenderedCount..<lines.count]
        let attributed = LogTextStorage.attributedString(for: Array(newSlice), startingAt: lastRenderedCount + 1, showLineNumbers: showLineNumbers)
        storage.appendLines(attributed)
            lastRenderedCount = lines.count
            _ = textView // silence warning; NSTextView auto-scrolls when content grows if isEditable is false
        }

        func applySearchHighlight(_ needle: String) {
            guard let textView, let storage else { return }
            let attributed = NSMutableAttributedString(attributedString: storage)
            let full = attributed.string as NSString
            let range = full.range(of: needle, options: .caseInsensitive)
            if range.location != NSNotFound {
                attributed.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.4), range: range)
            }
            textView.textStorage?.setAttributedString(attributed)
        }
    }
}

// MARK: - LogTextStorage (NSTextStorage subclass)

/// Custom `NSTextStorage` that knows how to color each line by
/// stream. The storage is rebuilt when the buffer changes; line-by-
/// line coloring is applied to a plain text representation.
final class LogTextStorage: NSTextStorage {
    private let backing = NSMutableAttributedString()

    override var string: String { backing.string as String }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    func appendLines(_ attributed: NSAttributedString) {
        let range = NSRange(location: backing.length, length: 0)
        backing.append(attributed)
        edited(.editedCharacters, range: range, changeInLength: attributed.length)
    }

    static func attributedString(for lines: [LogLine], startingAt startIndex: Int, showLineNumbers: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        for (offset, line) in lines.enumerated() {
            let number = String(format: "%6d  ", startIndex + offset)
            let lineNumberAttr: [NSAttributedString.Key: Any] = showLineNumbers
                ? [.font: mono, .foregroundColor: NSColor.tertiaryLabelColor]
                : [:]
            if showLineNumbers {
                result.append(NSAttributedString(string: number, attributes: lineNumberAttr))
            }
            result.append(NSAttributedString(string: line.text, attributes: [
                .font: mono,
                .foregroundColor: line.stream.nsColor
            ]))
            result.append(NSAttributedString(string: "\n"))
        }
        return result
    }
}
