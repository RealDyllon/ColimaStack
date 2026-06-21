//
//  MotionFeedback.swift
//  ColimaStack
//
//  Hover states, focus rings, lifecycle flashes, toasts, and
//  VoiceOver announcement throttling. Implements the motion-feedback
//  capability from the apple-design-award-ui change.
//

import AppKit
import Combine
import SwiftUI

// MARK: - Hover state

/// Adds a subtle background highlight on hover to a view. Honors
/// Reduce Motion by skipping the transition.
struct HoverHighlightModifier: ViewModifier {
    @State private var isHovered = false
    let base: Color
    let hover: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? hover : base)
                    .animation(.easeInOut(duration: 0.12), value: isHovered)
            )
            .onHover { isHovered = $0 }
    }
}

extension View {
    /// Apply a hover-state background highlight.
    func hoverHighlight(base: Color = .clear, hover: Color = Color.accentColor.opacity(0.08), cornerRadius: CGFloat = 8) -> some View {
        modifier(HoverHighlightModifier(base: base, hover: hover, cornerRadius: cornerRadius))
    }
}

// MARK: - Focus ring

/// A 2pt focus ring around any view. Thicker under Increase Contrast.
struct FocusRingModifier: ViewModifier {
    let color: Color
    let width: CGFloat
    let cornerRadius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(color.opacity(0.9), lineWidth: contrast == .increased ? width + 1 : width)
        )
    }
}

extension View {
    /// Apply a token-driven focus ring.
    func focusRing(color: Color = .accentColor, width: CGFloat = 2, cornerRadius: CGFloat = 8) -> some View {
        modifier(FocusRingModifier(color: color, width: width, cornerRadius: cornerRadius))
    }
}

// MARK: - Lifecycle flash

/// A 220ms-in / 600ms-out tinted flash for success/failure row
/// animations. Re-applies each time `trigger` changes.
struct LifecycleFlashModifier: ViewModifier {
    let trigger: UUID
    let color: Color
    @State private var isFlashing = false
    @State private var flashTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .background(
                color.opacity(isFlashing ? 0.18 : 0)
                    .animation(.easeInOut(duration: 0.22), value: isFlashing)
            )
            .onChange(of: trigger) { _, _ in
                flashTask?.cancel()
                isFlashing = true
                flashTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 220_000_000)
                    isFlashing = false
                }
            }
    }
}

extension View {
    /// Apply a flash animation when `trigger` changes (e.g. a row
    /// transitions to .running).
    func lifecycleFlash(trigger: UUID, color: Color = .green) -> some View {
        modifier(LifecycleFlashModifier(trigger: trigger, color: color))
    }
}

// MARK: - Inline progress

/// A trailing-edge progress indicator for rows under operation.
struct InlineProgress: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .frame(width: 14, height: 14)
            .accessibilityLabel("Operation in progress")
    }
}

// MARK: - Toast center

/// In-app toast notifications. The SwiftUI overlay sits at the
/// top-right of the main window. Max 3 toasts; 5s auto-dismiss;
/// hover pauses the auto-dismiss.
@MainActor
public final class ToastCenter: ObservableObject {
    public struct Toast: Identifiable {
        public let id: UUID
        public let title: String
        public let message: String
        public let tone: Tone
        public let actionTitle: String?
        public let actionHandler: (() -> Void)?

        public enum Tone: String, Hashable {
            case success, warning, error, info
        }

        public init(
            id: UUID = UUID(),
            title: String,
            message: String,
            tone: Tone,
            actionTitle: String? = nil,
            actionHandler: (() -> Void)? = nil
        ) {
            self.id = id
            self.title = title
            self.message = message
            self.tone = tone
            self.actionTitle = actionTitle
            self.actionHandler = actionHandler
        }
    }

    @Published public private(set) var toasts: [Toast] = []
    public static let maxToasts = 3
    public static let autoDismissSeconds: TimeInterval = 5

    public init() {}

    public func show(_ toast: Toast) {
        toasts.append(toast)
        if toasts.count > Self.maxToasts {
            toasts.removeFirst(toasts.count - Self.maxToasts)
        }
        scheduleDismiss(for: toast)
    }

    public func dismiss(id: UUID) {
        toasts.removeAll { $0.id == id }
    }

    private func scheduleDismiss(for toast: Toast) {
        let id = toast.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.autoDismissSeconds * 1_000_000_000))
            if toasts.contains(where: { $0.id == id }) {
                dismiss(id: id)
            }
        }
    }
}

extension ToastCenter.Toast.Tone {
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        }
    }
}

/// SwiftUI overlay for ToastCenter. Mounted at the top of the
/// main window's NavigationSplitView.
struct ToastOverlay: View {
    @ObservedObject var center: ToastCenter

    var body: some View {
        VStack(spacing: 8) {
            ForEach(center.toasts) { toast in
                toastView(toast)
            }
        }
        .padding(.top, 12)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .allowsHitTesting(!center.toasts.isEmpty)
    }

    @ViewBuilder
    private func toastView(_ toast: ToastCenter.Toast) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: toast.tone.iconName)
                .foregroundStyle(toast.tone.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.subheadline.weight(.semibold))
                if !toast.message.isEmpty {
                    Text(toast.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle = toast.actionTitle, let handler = toast.actionHandler {
                Button(actionTitle) { handler() }
                    .buttonStyle(.bordered)
            }
            Button {
                center.dismiss(id: toast.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - VoiceOver announcement throttling

/// Wraps `AccessibilityNotification.Announcement` with a per-3s
/// throttle so VoiceOver doesn't queue dozens of state-change
/// announcements.
@MainActor
public final class VoiceOverAnnouncer {
    public static let shared = VoiceOverAnnouncer()
    private(set) public var lastAnnouncementAt: Date = .distantPast
    private let minimumInterval: TimeInterval = 3

    public func announce(_ message: String) {
        let now = Date()
        if now.timeIntervalSince(lastAnnouncementAt) < minimumInterval { return }
        lastAnnouncementAt = now
        if #available(macOS 13.0, *) {
            AccessibilityNotification.Announcement(message).post()
        } else {
            NSAccessibility.post(
                element: NSApp.mainWindow as Any,
                notification: .announcementRequested,
                userInfo: [
                    NSAccessibility.NotificationUserInfoKey.announcement: message,
                    NSAccessibility.NotificationUserInfoKey.priority: NSAccessibilityPriorityLevel.high.rawValue
                ]
            )
        }
    }
}
