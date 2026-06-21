## ADDED Requirements

### Requirement: Subscribe to Docker engine events for the selected profile
The system SHALL maintain a long-lived subscription to Docker engine events for the selected profile's Docker context/socket, producing delta events for container, image, volume, and network changes. The subscription SHALL use the streaming `docker events --format '{{json .}}'` process against the selected profile's Docker context.

#### Scenario: A container start produces an item-added delta
- **WHEN** a container starts in the selected profile's Docker context
- **THEN** the source publishes a docker `ItemAdded`/`ItemModified` event carrying the container id and the updated container resource

#### Scenario: A container destroy produces an item-removed delta
- **WHEN** a container is destroyed in the selected profile's Docker context
- **THEN** the source publishes a docker `ItemRemoved` event carrying the container id

### Requirement: Bootstrap with a full snapshot before applying deltas
The system SHALL run one `docker ps -a`, `docker images`, `docker volume ls`, and `docker network ls` snapshot when the source starts (and on each reconnect), publish a `SnapshotReplaced` event, and THEN begin applying streaming deltas. Deltas SHALL be applied on top of the bootstrapped state.

#### Scenario: First state is a full snapshot
- **WHEN** the docker event source starts for a profile
- **THEN** the reducer receives a `SnapshotReplaced` event containing the full container/image/volume/network lists before any streaming delta

#### Scenario: Reconnect re-bootstraps
- **WHEN** the docker events stream drops and reconnects
- **THEN** the source re-runs the bootstrap snapshot and publishes a fresh `SnapshotReplaced` before resuming deltas, so any changes missed during the gap are reconciled

### Requirement: Translate engine events to typed deltas
The system SHALL translate each `docker events` JSON line into a typed `RuntimeEvent` delta keyed by resource kind (`container`, `image`, `volume`, `network`) and change kind (`added`, `modified`, `removed`). The translation SHALL use the same field mapping as the existing `DockerResourceService` parsers so delta records are shape-compatible with the bootstrapped snapshot records.

#### Scenario: A docker event line becomes a typed delta
- **WHEN** the source reads `{"status":"start","id":"abc","Type":"container","Actor":{…}}`
- **THEN** the source publishes a `docker .container .modified` event with a `DockerContainerResource` matching the existing parser's field mapping

### Requirement: Stop the subscription on profile switch or profile stop
The system SHALL stop the docker events subscription when the selected profile changes or when the selected profile transitions to a non-running state. Stopping SHALL terminate the streaming process and release its resources.

#### Scenario: Profile switch stops the stream
- **WHEN** the user switches from profile "default" to "dev"
- **THEN** the docker events process for "default" is terminated before the source for "dev" starts

#### Scenario: Profile stop stops the stream
- **WHEN** the selected profile transitions to `.stopped`
- **THEN** the docker events subscription stops and the docker connection state becomes `disconnected`

### Requirement: Skip subscription for non-Docker runtimes
The system SHALL NOT start a docker events subscription when the selected profile's runtime is not `.docker` (e.g. `containerd`, `incus`). The docker connection state SHALL be `disconnected` with a reason indicating the runtime is not Docker.

#### Scenario: Containerd profile does not subscribe to docker events
- **WHEN** the selected profile uses the `containerd` runtime
- **THEN** no docker events process is started and the docker connection state is `disconnected` with a "not Docker" reason

### Requirement: Malformed event lines do not crash the stream
The system SHALL drop a malformed `docker events` JSON line, emit a `BackendIssue` (severity `.warning`, source `.docker`) describing the dropped line, and continue reading the stream.

#### Scenario: A bad JSON line is dropped with a warning
- **WHEN** the stream produces a line that is not valid JSON
- **THEN** the source drops the line, publishes a warning `BackendIssue`, and does not terminate the subscription
