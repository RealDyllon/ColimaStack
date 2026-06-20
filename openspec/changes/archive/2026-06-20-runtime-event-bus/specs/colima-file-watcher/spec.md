## ADDED Requirements

### Requirement: Watch Colima profile files for changes
The system SHALL register `DispatchSource` file-system object sources on the selected profile's `colima.yaml`, `daemon/daemon.log`, and the lima instance state file, watching for `.write`, `.delete`, `.rename`, and `.extend` vnode events. The watchers SHALL be scoped to the selected profile and restarted on profile switch.

#### Scenario: A colima.yaml edit is detected
- **WHEN** the selected profile's `colima.yaml` is modified on disk
- **THEN** the file watcher fires an event for that file

#### Scenario: A daemon log append is detected
- **WHEN** the selected profile's `daemon.log` grows
- **THEN** the file watcher fires an event for `daemon.log`

### Requirement: Trigger an on-demand status probe on config/state change
The system SHALL trigger a single on-demand `colima status --json` probe when `colima.yaml` or the lima state file changes, and SHALL publish the resulting `ColimaStatusDetail` as a `ColimaStatusUpdated` event. The probe SHALL NOT run a full `refreshAll` and SHALL NOT re-probe tool versions.

#### Scenario: A config change triggers one status probe
- **WHEN** `colima.yaml` changes
- **THEN** the watcher runs exactly one `colima status --json` for the selected profile and publishes a `ColimaStatusUpdated` event with the result

#### Scenario: A status probe does not re-probe tools
- **WHEN** a file-event-triggered status probe runs
- **THEN** no `colima version`/`docker version`/`kubectl version` subprocess is spawned

### Requirement: Tail the daemon log live
The system SHALL tail the selected profile's `daemon/daemon.log` by reading from the last-consumed offset on each change event, redacting the new bytes with `EnvironmentRedactor.redacted`, and publishing an appended-log event. The system SHALL NOT re-read the entire file on each change.

#### Scenario: New log bytes are appended
- **WHEN** the daemon log grows by N bytes
- **THEN** the watcher reads only those N bytes (seeked from the prior offset), redacts them, and publishes an append event; the existing log content is not re-read

#### Scenario: Log rotation is handled
- **WHEN** the daemon log file is truncated or rotated (size shrinks below the prior offset)
- **THEN** the watcher resets its offset to 0 and re-reads from the start of the current file

### Requirement: Stop watchers on profile switch
The system SHALL cancel and release all `DispatchSource` watchers and close held `FileHandle`s for the previous profile when the selected profile changes, before starting watchers for the new profile.

#### Scenario: Profile switch releases old file handles
- **WHEN** the user switches from profile "default" to "dev"
- **THEN** the watchers and file handles for "default" are cancelled and closed before watchers for "dev" are registered

### Requirement: Handle missing files gracefully
The system SHALL NOT fail when a watched file does not exist. The watcher SHALL poll for the file's appearance at a short interval (or re-register on creation) and publish a `connectionState` of `connecting` until the file appears, then `connected`.

#### Scenario: A missing daemon log does not crash
- **WHEN** the selected profile has no `daemon.log` yet
- **THEN** the watcher remains in `connecting` and does not crash; when the file appears it begins tailing

### Requirement: Coalesce rapid log growth
The system SHALL coalesce rapid `daemon.log` growth per the `runtime-event-bus` coalescing requirement, batching new bytes within a small time window before publishing an appended-log event, to avoid flooding the reducer during a verbose operation.

#### Scenario: A burst of log growth is coalesced
- **WHEN** the daemon log grows by many small writes in a 50ms window
- **THEN** the watcher publishes a single appended-log event containing the coalesced bytes rather than one event per write
