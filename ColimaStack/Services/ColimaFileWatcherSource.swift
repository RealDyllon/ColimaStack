import Foundation
import Darwin

/// Event source that watches Colima profile files (`colima.yaml`, `daemon/daemon.log`,
/// and the lima instance state) via `DispatchSource` vnode sources. On `colima.yaml` or
/// lima-state changes, triggers a single on-demand `colima status --json` probe and
/// publishes `ColimaStatusUpdated`. On `daemon.log` changes, tails from the last-read
/// offset and publishes `LogAppended` (coalesced).
///
/// Missing files are polled for appearance at a short interval until they exist.
final class ColimaFileWatcherSource: RuntimeEventSource, @unchecked Sendable {
    private let profile: ColimaProfile
    private let colima: ColimaControlling
    private let environment: [String: String]
    private let fileManager: FileManager
    private let coalesceInterval: TimeInterval

    init(
        profile: ColimaProfile,
        colima: ColimaControlling,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        coalesceInterval: TimeInterval = 0.05
    ) {
        self.profile = profile
        self.colima = colima
        self.environment = environment
        self.fileManager = fileManager
        self.coalesceInterval = coalesceInterval
    }

    func events() -> AsyncThrowingStream<RuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.connectionStateChanged(source: .colima, state: .connecting))

                let home = ColimaPaths.home(environment: self.environment, fileManager: self.fileManager)
                let configURL = home.appendingPathComponent("\(self.profile.name)/colima.yaml")
                let logURL = ColimaPaths.daemonLog(profile: self.profile.name, environment: self.environment, fileManager: self.fileManager)
                let limaStateURL = home.appendingPathComponent("_lima/\(self.profile.name)/lima.yaml")

                // Track state shared between the watcher and the file-handle tail.
                let logTail = LogTailState()

                // Set up watchers for each file. Missing files are polled for appearance.
                let watcherTask = Task {
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask { await self.watchFile(url: configURL, label: "config", continuation: continuation) {
                            await self.triggerStatusProbe(continuation: continuation)
                        } }
                        group.addTask { await self.watchFile(url: limaStateURL, label: "lima-state", continuation: continuation) {
                            await self.triggerStatusProbe(continuation: continuation)
                        } }
                        group.addTask { await self.watchFile(url: logURL, label: "daemon-log", continuation: continuation) {
                            await self.tailLog(url: logURL, tail: logTail, continuation: continuation)
                        } }
                    }
                }

                // Publish connected once watchers are set up.
                continuation.yield(.connectionStateChanged(source: .colima, state: .connected))

                // Wait for cancellation.
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000)
                    } catch {
                        break
                    }
                }
                watcherTask.cancel()
                continuation.finish()
            }
        }
    }

    // MARK: - File watching

    private func watchFile(url: URL, label: String, continuation: AsyncThrowingStream<RuntimeEvent, Error>.Continuation, onChange: @escaping @Sendable () async -> Void) async {
        while !Task.isCancelled {
            // Wait for the file to appear if it doesn't exist.
            while !Task.isCancelled, !fileManager.fileExists(atPath: url.path) {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }
            if Task.isCancelled { return }

            // Open a file handle and register a DispatchSource vnode source.
            do {
                let handle = try FileHandle(forReadingFrom: url)
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: handle.fileDescriptor,
                    eventMask: [.write, .delete, .rename, .extend],
                    queue: DispatchQueue.global(qos: .utility)
                )
                let box = WatcherBox(handle: handle, source: source)
                source.setEventHandler {
                    // Re-register if the file was deleted/renamed.
                    if box.source == nil { return }
                    Task { await onChange() }
                    if source.data.contains(.delete) || source.data.contains(.rename) {
                        box.source = nil
                        source.cancel()
                    }
                }
                source.setCancelHandler {
                    try? handle.close()
                }
                source.resume()

                // Wait until cancelled or the source is invalidated (file deleted/renamed).
                while !Task.isCancelled, box.source != nil {
                    do {
                        try await Task.sleep(nanoseconds: 200_000_000)
                    } catch {
                        break
                    }
                }
                source.cancel()
            } catch {
                // File couldn't be opened; retry after a delay.
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    // MARK: - Status probe

    private func triggerStatusProbe(continuation: AsyncThrowingStream<RuntimeEvent, Error>.Continuation) async {
        do {
            let detail = try await colima.status(profile: profile.name)
            continuation.yield(.colimaStatusUpdated(detail))
        } catch {
            // Status probe failed; publish an issue but don't crash the watcher.
            continuation.yield(.issue(BackendIssue(
                severity: .warning,
                source: .colima,
                title: "Colima status probe failed",
                message: error.localizedDescription
            )))
        }
    }

    // MARK: - Log tailing

    private func tailLog(url: URL, tail: LogTailState, continuation: AsyncThrowingStream<RuntimeEvent, Error>.Continuation) async {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            // Seek to end on first open.
            let currentSize = try handle.seekToEnd()
            let initialOffset = tail.load()
            if initialOffset == 0 {
                tail.store(currentSize)
            } else if currentSize < initialOffset {
                // File was truncated/rotated; reset to 0.
                tail.store(0)
                try handle.seek(toOffset: 0)
            } else {
                try handle.seek(toOffset: initialOffset)
            }

            let availableData = handle.availableData
            if !availableData.isEmpty {
                let text = String(decoding: availableData, as: UTF8.self)
                let redacted = EnvironmentRedactor.redacted(text)
                if !redacted.isEmpty {
                    continuation.yield(.logAppended(redacted))
                }
                tail.add(availableData.count)
            }
            try handle.close()
        } catch {
            // Log read failed; ignore — will retry on next file-change event.
        }
    }
}

// MARK: - Shared state boxes

private final class WatcherBox: @unchecked Sendable {
    var handle: FileHandle
    var source: DispatchSourceFileSystemObject?
    init(handle: FileHandle, source: DispatchSourceFileSystemObject?) {
        self.handle = handle
        self.source = source
    }
}

private final class LogTailState: @unchecked Sendable {
    private let lock = NSLock()
    private var _offset: UInt64 = 0

    func load() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        return _offset
    }

    func store(_ value: UInt64) {
        lock.lock(); defer { lock.unlock() }
        _offset = value
    }

    func add(_ value: Int) {
        lock.lock(); defer { lock.unlock() }
        _offset &+= UInt64(value)
    }
}
