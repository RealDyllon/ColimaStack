# kubernetes-watch Specification

## Purpose
TBD - created by archiving change runtime-event-bus. Update Purpose after archive.
## Requirements
### Requirement: Watch Kubernetes resources via kubectl get -w
The system SHALL maintain a long-lived `kubectl --context <ctx> get <resource> -A -w -o json` stream per watched resource kind (nodes, namespaces, pods, services, deployments) for the selected profile's Kubernetes context, producing delta events from the streamed `{ "type": "ADDED|MODIFIED|DELETED", "object": {…} }` objects.

#### Scenario: A pod phase change produces a modified delta
- **WHEN** a watched pod transitions from `Pending` to `Running`
- **THEN** the source publishes a kubernetes `ItemModified` event for that pod with the updated `phase`

#### Scenario: A pod deletion produces a removed delta
- **WHEN** a watched pod is deleted
- **THEN** the source publishes a kubernetes `ItemRemoved` event carrying the pod's identity

### Requirement: Bootstrap with a full snapshot before watching
The system SHALL run one `kubectl get <resource> -A -o json` snapshot per resource kind when the watch starts (and on each reconnect), publish a `SnapshotReplaced` event, and THEN begin applying watch deltas on top of the bootstrapped state.

#### Scenario: First kubernetes state is a full snapshot
- **WHEN** the kubernetes watch starts for a profile with Kubernetes enabled
- **THEN** the reducer receives `SnapshotReplaced` events for nodes, namespaces, pods, services, and deployments before any watch deltas

#### Scenario: Reconnect re-bootstraps
- **WHEN** a watch stream drops and reconnects
- **THEN** the source re-runs the bootstrap snapshot for that resource kind and publishes a fresh `SnapshotReplaced` before resuming deltas

### Requirement: Translate watch objects to typed deltas
The system SHALL translate each watch object into a typed `RuntimeEvent` delta keyed by resource kind and change kind (`added`, `modified`, `removed`), using the same field mapping as the existing `KubernetesResourceService` parsers so delta records are shape-compatible with the bootstrapped snapshot records.

#### Scenario: A watch object becomes a typed pod delta
- **WHEN** the source reads `{"type":"MODIFIED","object":{"kind":"Pod",…}}`
- **THEN** the source publishes a `kubernetes .pod .modified` event with a `KubernetesPodResource` matching the existing parser's field mapping

### Requirement: Stop watches on profile switch or Kubernetes disable
The system SHALL stop all kubernetes watch streams when the selected profile changes or when Kubernetes is disabled on the selected profile. Stopping SHALL terminate the streaming `kubectl` processes.

#### Scenario: Profile switch stops all watches
- **WHEN** the user switches from profile "default" to "dev"
- **THEN** all kubernetes watch processes for "default" are terminated before watches for "dev" are considered

#### Scenario: Disabling Kubernetes stops watches
- **WHEN** Kubernetes is disabled on the selected profile
- **THEN** all kubernetes watch streams stop and the kubernetes connection state becomes `disconnected`

### Requirement: Do not start watches when Kubernetes is disabled
The system SHALL NOT start any kubernetes watch when the selected profile has `kubernetes.enabled == false`. The kubernetes connection state SHALL be `disconnected` with a reason indicating Kubernetes is disabled.

#### Scenario: Kubernetes-disabled profile does not watch
- **WHEN** the selected profile has Kubernetes disabled
- **THEN** no `kubectl get -w` process is started and the kubernetes connection state is `disconnected` with a "Kubernetes disabled" reason

### Requirement: Reconnect watches with backoff
The system SHALL reconnect a dropped kubernetes watch stream with exponential backoff (per the `runtime-event-bus` reconnect requirement), re-bootstrapping the snapshot before resuming deltas.

#### Scenario: A dropped watch reconnects
- **WHEN** a `kubectl get -w` process exits unexpectedly
- **THEN** the source enters `reconnecting`, waits per the backoff schedule, re-bootstraps the snapshot, and resumes the watch

### Requirement: Malformed watch lines do not crash the stream
The system SHALL drop a malformed watch JSON line, emit a `BackendIssue` (severity `.warning`, source `.kubernetes`) describing the dropped line, and continue reading the stream.

#### Scenario: A bad watch line is dropped with a warning
- **WHEN** a watch stream produces a line that is not valid JSON
- **THEN** the source drops the line, publishes a warning `BackendIssue`, and does not terminate the watch

