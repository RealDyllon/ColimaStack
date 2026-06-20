## ADDED Requirements

### Requirement: Runtime event bus fans in push events from all sources
The system SHALL provide a single `RuntimeEventBus` that fans in `RuntimeEvent` values from Docker, Kubernetes, and Colima file sources into one `AsyncStream<RuntimeEvent>` consumed by the `AppState` reducer. Each event SHALL carry a `source` discriminator and a typed payload.

#### Scenario: Events from multiple sources arrive in one stream
- **WHEN** a docker container starts and a kubernetes pod changes phase simultaneously
- **THEN** the reducer receives both events on the same stream and applies each delta to the appropriate slice of state

#### Scenario: Event payload is typed and discriminated
- **WHEN** the reducer reads an event
- **THEN** the event exposes a `source` (`.docker`, `.kubernetes`, `.colima`, `.command`) and a typed payload that the reducer can switch on without string parsing

### Requirement: AppState reduces events to delta updates without full re-polling
The system SHALL implement `AppState` as a reducer that applies each `RuntimeEvent` as a delta to the minimal affected slice of published state, rather than replacing the entire snapshot. The reducer SHALL NOT spawn subprocesses in response to a delta event.

#### Scenario: A container delta updates only the container list
- **WHEN** a `docker` `ItemModified` event arrives for one container
- **THEN** only the affected container in `backendSnapshot.docker.containers` is updated and no `docker ps` subprocess is spawned

#### Scenario: A pod delta updates only the pod list
- **WHEN** a `kubernetes` `ItemModified` event arrives for one pod
- **THEN** only the affected pod in `backendSnapshot.kubernetes.pods` is updated and no `kubectl get pods` subprocess is spawned

### Requirement: Per-profile source lifecycle follows selection
The system SHALL start all event sources for the currently selected profile and SHALL stop them when the selected profile changes. Switching profiles SHALL cancel in-flight sources for the previous profile before starting sources for the new one.

#### Scenario: Switching profiles restarts sources
- **WHEN** the user selects a different profile
- **THEN** the bus cancels the docker, kubernetes, and colima file sources for the previous profile and starts fresh sources scoped to the new profile

#### Scenario: Sources are scoped to the selected profile
- **WHEN** a docker events source is running for profile "default"
- **THEN** the source uses the docker context and socket for "default" and does not receive events from other profiles

### Requirement: Event bus survives main window close
The system SHALL own the `RuntimeEventBus` lifecycle at the application scope (in `ColimaStackApp`), not at the `ContentView` scope, so that closing the main window does not stop event delivery. The `MenuBarExtra` SHALL continue to reflect current state after the window is closed.

#### Scenario: Menu bar stays live after window close
- **WHEN** the user closes the main window while a profile is running
- **THEN** the menu bar label and menu continue to update from live events (e.g. a subsequent `colima stop` is reflected) without reopening the window

### Requirement: Per-source connection state is tracked and surfaced
The system SHALL track a `ConnectionState` (`disconnected`, `connecting`, `connected`, `reconnecting`, `failed`) for each event source and SHALL expose an aggregated per-profile `RuntimeConnectionStatus` that the UI can observe.

#### Scenario: Socket loss is reported as reconnecting
- **WHEN** the docker events stream terminates unexpectedly
- **THEN** the docker source's `connectionState` becomes `reconnecting` and the UI can display that the docker feed is reconnecting

#### Scenario: Permanent failure is reported
- **WHEN** a source exhausts reconnect attempts or the required tool is missing
- **THEN** the source's `connectionState` becomes `failed` with a reason and the UI can display the failure without crashing

### Requirement: Sources reconnect with backoff
The system SHALL reconnect any failed event source using exponential backoff with jitter, capped at a maximum interval. Reconnect SHALL be attempted until the source is stopped by a profile switch or the user disabling the relevant runtime.

#### Scenario: Backoff increases up to a cap
- **WHEN** a source fails repeatedly
- **THEN** the delay before each successive reconnect attempt grows exponentially up to a configured cap and is not increased beyond the cap

#### Scenario: Reconnect stops on profile switch
- **WHEN** the user switches profiles while a source is in `reconnecting`
- **THEN** the reconnect attempts for the previous profile are cancelled and no further events from the old profile are delivered

### Requirement: High-frequency events are coalesced before publish
The system SHALL coalesce high-frequency event streams (log tail chunks and `docker stats` samples) in the source before publishing to the reducer, batching within a small time window or byte threshold, to avoid flooding the main actor.

#### Scenario: A burst of log lines is published as one batch
- **WHEN** the daemon log grows by many lines in a short window
- **THEN** the colima file source coalesces the new bytes and publishes a single appended-log event rather than one event per line

### Requirement: Tool presence checks run on a slow timer, not per event
The system SHALL probe tool presence and version (`colima`, `docker`, `kubectl`, `limactl`) on a slow timer (60–120 seconds) and on startup, NOT on every event or every refresh. Tool versions SHALL be cached for the session.

#### Scenario: Tool versions are not re-probed every refresh
- **WHEN** the app has been running for 30 seconds and many events have been processed
- **THEN** no `colima version`/`docker version`/`kubectl version`/`limactl --version` subprocess has been spawned since startup (or the last slow-timer fire)

### Requirement: Polling path is retained behind a feature flag during migration
The system SHALL gate the event-driven path behind a `useEventBus` flag. When the flag is off, the system SHALL behave exactly as the current polling implementation (`runAutoRefreshLoop`, `refreshAll`, `refreshGeneration`). The flag SHALL default off until phase 3.

#### Scenario: Flag off preserves current behavior
- **WHEN** `useEventBus` is off
- **THEN** the app uses `runAutoRefreshLoop` and `refreshAll` as today and no event sources are started

#### Scenario: Flag on disables polling
- **WHEN** `useEventBus` is on
- **THEN** `runAutoRefreshLoop` does not run and state is driven by the event bus
