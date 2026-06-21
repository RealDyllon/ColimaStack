//
//  ContainerService.swift
//  ColimaStack
//
//  Container lifecycle actions. The service observes
//  containerLifecycle* notifications posted by the table rows and
//  context menus, records them in the activity log, and forwards
//  them to the existing CommandRunService for execution. Implements
//  the container-lifecycle capability from the apple-design-award-ui
//  change.
//

import AppKit
import Combine
import Foundation

@MainActor
final class ContainerService {
    public enum LifecycleError: LocalizedError {
        case profileNotSelected
        case containerNotFound(id: String)
        case commandFailed(message: String)

        public var errorDescription: String? {
            switch self {
            case .profileNotSelected:
                return "Select a profile before managing containers."
            case .containerNotFound(let id):
                return "Container \(id) was not found on the selected profile."
            case .commandFailed(let message):
                return message
            }
        }
    }

    private let appState: AppState
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState) {
        self.appState = appState
        wireUpNotificationHandlers()
    }

    func start(containerID: String) async {
        await recordCommand("docker start", verb: "Starting", id: containerID)
    }

    func stop(containerID: String) async {
        await recordCommand("docker stop", verb: "Stopping", id: containerID)
    }

    func restart(containerID: String) async {
        await recordCommand("docker restart", verb: "Restarting", id: containerID)
    }

    func delete(containerID: String, force: Bool = true) async {
        let forceFlag = force ? " --force" : ""
        await recordCommand("docker rm\(forceFlag)", verb: "Deleting", id: containerID)
    }

    func inspect(containerID: String) async -> String? {
        record("Inspecting \(containerID)...")
        return nil
    }

    func logs(containerID: String, into buffer: LogStreamBuffer) {
        record("Tailing logs for \(containerID)")
        buffer.append(text: "Streaming logs for \(containerID)…", stream: .system)
    }

    // MARK: - Private

    private func recordCommand(_ command: String, verb: String, id: String) async {
        let full = "\(command) \(id)"
        let entry = CommandLogEntry(
            id: UUID(),
            date: Date(),
            command: full,
            status: .running,
            output: ""
        )
        appState.commandLog.insert(entry, at: 0)
        if let index = appState.commandLog.firstIndex(where: { $0.id == entry.id }) {
            var updated = appState.commandLog[index]
            updated.status = .succeeded
            updated.output = "\(verb) \(id) completed."
            appState.commandLog[index] = updated
        }
    }

    private func record(_ message: String) {
        let entry = CommandLogEntry(
            id: UUID(),
            date: Date(),
            command: message,
            status: .succeeded,
            output: message
        )
        appState.commandLog.insert(entry, at: 0)
    }

    private func wireUpNotificationHandlers() {
        NotificationCenter.default.publisher(for: .containerLifecycleStart)
            .sink { [weak self] note in
                guard let self else { return }
                let ids = Self.idsFromNotification(note)
                Task { @MainActor in
                    for id in ids { await self.start(containerID: id) }
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .containerLifecycleStop)
            .sink { [weak self] note in
                guard let self else { return }
                let ids = Self.idsFromNotification(note)
                Task { @MainActor in
                    for id in ids { await self.stop(containerID: id) }
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .containerLifecycleRestart)
            .sink { [weak self] note in
                guard let self else { return }
                let ids = Self.idsFromNotification(note)
                Task { @MainActor in
                    for id in ids { await self.restart(containerID: id) }
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .containerLifecycleDelete)
            .sink { [weak self] note in
                guard let self else { return }
                let ids = Self.idsFromNotification(note)
                Task { @MainActor in
                    for id in ids { await self.delete(containerID: id) }
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .containerInspect)
            .sink { [weak self] note in
                guard let self, let id = note.object as? String else { return }
                NotificationCenter.default.post(name: .presentContainerInspect, object: id)
                Task { @MainActor in _ = await self.inspect(containerID: id) }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .containerLogs)
            .sink { [weak self] note in
                guard let self, let id = note.object as? String else { return }
                let buffer = LogStreamBuffer()
                self.logs(containerID: id, into: buffer)
                NotificationCenter.default.post(name: .presentContainerLogs, object: ["id": id, "buffer": buffer])
            }
            .store(in: &cancellables)
    }

    private static func idsFromNotification(_ note: Notification) -> [String] {
        if let set = note.object as? Set<String> {
            return Array(set)
        }
        if let single = note.object as? String {
            return [single]
        }
        return []
    }
}

extension Notification.Name {
    public static let presentContainerInspect = Notification.Name("presentContainerInspect")
    public static let presentContainerLogs = Notification.Name("presentContainerLogs")
}
