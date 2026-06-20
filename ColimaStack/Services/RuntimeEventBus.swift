import Foundation

// MARK: - Connection state

nonisolated enum ConnectionState: Hashable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(reason: String)
}

// MARK: - Runtime connection status (aggregated per profile)

nonisolated struct RuntimeConnectionStatus: Hashable, Sendable {
    var docker: ConnectionState = .disconnected
    var kubernetes: ConnectionState = .disconnected
    var colima: ConnectionState = .disconnected

    var anyDegraded: Bool {
        switch docker { case .failed, .reconnecting: return true; default: break }
        switch kubernetes { case .failed, .reconnecting: return true; default: break }
        switch colima { case .failed, .reconnecting: return true; default: break }
        return false
    }

    var allConnected: Bool {
        docker == .connected && kubernetes == .connected && colima == .connected
    }
}

// MARK: - Resource kinds

nonisolated enum DockerResourceKind: String, Hashable, Codable, Sendable {
    case container
    case image
    case volume
    case network
}

nonisolated enum KubernetesResourceKind: String, Hashable, Codable, Sendable {
    case node
    case namespace
    case pod
    case service
    case deployment
}

nonisolated enum ChangeKind: Hashable, Sendable {
    case added
    case modified
    case removed
}

// MARK: - Runtime event

nonisolated enum RuntimeEvent: Hashable, Sendable {
    case snapshotReplaced(source: EventSource, docker: DockerResourceSnapshotSlice?, kubernetes: KubernetesResourceSnapshotSlice?)
    case dockerItem(kind: DockerResourceKind, change: ChangeKind, id: String, record: AnyRuntimeRecord?)
    case kubernetesItem(kind: KubernetesResourceKind, change: ChangeKind, id: String, record: AnyRuntimeRecord?)
    case colimaStatusUpdated(ColimaStatusDetail)
    case logAppended(String)
    case statsSample(RuntimeUsageSample)
    case connectionStateChanged(source: EventSource, state: ConnectionState)
    case issue(BackendIssue)

    nonisolated enum EventSource: String, Hashable, Codable, Sendable {
        case docker
        case kubernetes
        case colima
    }
}

// MARK: - Slices / records

/// Lightweight, value-type slices used for snapshot replacement on the main actor.
nonisolated struct DockerResourceSnapshotSlice: Hashable, Sendable {
    var context: String
    var containers: [DockerContainerResource]
    var images: [DockerImageResource]
    var volumes: [DockerVolumeResource]
    var networks: [DockerNetworkResource]
    var stats: [DockerStatsResource]
    var diskUsage: [DockerDiskUsageResource]
}

nonisolated struct KubernetesResourceSnapshotSlice: Hashable, Sendable {
    var context: String
    var nodes: [KubernetesNodeResource]
    var namespaces: [KubernetesNamespaceResource]
    var pods: [KubernetesPodResource]
    var services: [KubernetesServiceResource]
    var deployments: [KubernetesDeploymentResource]
    var metrics: [KubernetesMetricResource]
}

/// Type-erased record (events carry the same resource models used by the existing snapshot
/// types so the reducer can apply deltas without re-parsing).
nonisolated enum AnyRuntimeRecord: Hashable, Sendable {
    case container(DockerContainerResource)
    case image(DockerImageResource)
    case volume(DockerVolumeResource)
    case network(DockerNetworkResource)
    case node(KubernetesNodeResource)
    case namespace(KubernetesNamespaceResource)
    case pod(KubernetesPodResource)
    case service(KubernetesServiceResource)
    case deployment(KubernetesDeploymentResource)
}

// MARK: - Event source protocol

nonisolated protocol RuntimeEventSource: Sendable {
    /// A throwing stream of `RuntimeEvent`s for this source. The stream SHOULD handle
    /// its own reconnect/backoff and only terminate when the source is stopped (profile
    /// switch / runtime disabled). Malformed data lines SHOULD be dropped with a
    /// `.issue` event rather than throwing.
    func events() -> AsyncThrowingStream<RuntimeEvent, Error>
}

// MARK: - Runtime event bus (fan-in)

/// Central fan-in of `RuntimeEvent` values from multiple long-lived sources into a single
/// `AsyncStream` consumed by the `AppState` reducer. Sources call `publish(_:)` to push
/// events; the consumer iterates `events`.
@MainActor
final class RuntimeEventBus {
    private let (stream, continuation) = AsyncStream<RuntimeEvent>.makeStream(
        of: RuntimeEvent.self,
        bufferingPolicy: .bufferingNewest(256)
    )

    var events: AsyncStream<RuntimeEvent> { stream }

    func publish(_ event: RuntimeEvent) {
        continuation.yield(event)
    }
}
