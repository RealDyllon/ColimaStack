import Combine
import Foundation
import SwiftUI

/// Owns the `RuntimeEventBus` lifecycle at the application scope (survives main window
/// close). Observes `AppState.selectedProfileID` and starts/stops per-profile event
/// sources. Feeds events to `AppState.reduce(_:)`.
@MainActor
final class RuntimeEventEngine: ObservableObject {
    @Published var connectionStatus = RuntimeConnectionStatus()

    private let bus = RuntimeEventBus()
    private var consumerTask: Task<Void, Never>?
    private var sourceGroup: Task<Void, Never>?
    private weak var appState: AppState?
    private var profileObservation: AnyCancellable?

    /// Source factories, set by the application wiring (Groups 4–6 provide real factories).
    /// A factory returns `nil` when the source is not applicable (e.g. docker source for
    /// a containerd profile).
    var dockerSourceFactory: ((ColimaProfile, ColimaStatusDetail) -> RuntimeEventSource?)?
    var kubernetesSourceFactory: ((ColimaProfile, ColimaStatusDetail) -> RuntimeEventSource?)?
    var colimaSourceFactory: ((ColimaProfile) -> RuntimeEventSource?)?

    func start(appState: AppState) {
        self.appState = appState
        startConsumer()
        profileObservation = appState.$selectedProfileID.sink { [weak self] id in
            self?.handleProfileChange(id)
        }
        handleProfileChange(appState.selectedProfileID)
    }

    func stop() {
        consumerTask?.cancel()
        sourceGroup?.cancel()
        profileObservation?.cancel()
    }

    // MARK: - Consumer

    private func startConsumer() {
        consumerTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.bus.events {
                self.appState?.reduce(event)
                if case let .connectionStateChanged(source, state) = event {
                    self.updateConnectionStatus(source: source, state: state)
                }
            }
        }
    }

    // MARK: - Profile change

    private func handleProfileChange(_ profileID: String?) {
        sourceGroup?.cancel()
        guard let appState, let profileID, let profile = appState.profiles.first(where: { $0.id == profileID }) else { return }
        let detail = appState.selectedProfileDetail ?? profile.statusDetail

        sourceGroup = Task { [weak self] in
            guard let self else { return }
            await withTaskGroup(of: Void.self) { group in
                if let factory = self.dockerSourceFactory, let source = factory(profile, detail) {
                    group.addTask { await self.runSource(source) }
                }
                if let factory = self.kubernetesSourceFactory, let source = factory(profile, detail) {
                    group.addTask { await self.runSource(source) }
                }
                if let factory = self.colimaSourceFactory, let source = factory(profile) {
                    group.addTask { await self.runSource(source) }
                }
            }
        }
    }

    private func runSource(_ source: RuntimeEventSource) async {
        do {
            for try await event in source.events() {
                if Task.isCancelled { break }
                bus.publish(event)
            }
        } catch {
            // A source exiting publishes a failed connection state so the UI can show it.
            // Sources are expected to handle their own reconnect/backoff internally; if
            // they exit permanently, the connection state reflects the failure.
        }
    }

    private func updateConnectionStatus(source: RuntimeEvent.EventSource, state: ConnectionState) {
        switch source {
        case .docker: connectionStatus.docker = state
        case .kubernetes: connectionStatus.kubernetes = state
        case .colima: connectionStatus.colima = state
        }
    }
}
