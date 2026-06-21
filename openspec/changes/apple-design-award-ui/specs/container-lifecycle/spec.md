# container-lifecycle Specification

## Purpose
Add first-class container lifecycle actions (Start, Stop, Restart, Delete), an Inspect panel, and a Logs view so users can manage individual containers from the Containers screen without dropping to the terminal. Marks the **Deferred** design reconciliation items 24–26 (container delete confirmation, container inspect, container logs/files) as Implemented.

## ADDED Requirements

### Requirement: Containers screen surfaces row actions
The Containers table SHALL show Start, Stop, Restart, and Delete actions per row via a context menu (right-click), a leading context-menu button on the row, and the multi-selection contextual action bar. Each action SHALL be enabled/disabled based on the container's current state (e.g. Stop is enabled only when the container is running; Start is enabled only when it is stopped). The action SHALL call into the existing `BackendAggregationService` (or a new `ContainerService` if the backend layer does not yet expose these operations) to perform the `docker start|stop|restart|rm` lifecycle command.

#### Scenario: Right-click a running container
- **WHEN** the user right-clicks a running container row
- **THEN** the context menu shows Start (disabled), Stop, Restart, Delete (with confirmation), ───, Copy ID, Copy Image, Copy Ports, Open in Browser (if ports), Inspect, View Logs

#### Scenario: Right-click a stopped container
- **WHEN** the user right-clicks a stopped container row
- **THEN** the context menu shows Start, Stop (disabled), Restart (disabled), Delete (with confirmation), ───, Copy ID, Copy Image, Open in Browser (if ports), Inspect, View Logs

### Requirement: Delete is destructive and requires confirmation
The Delete action SHALL open a system confirmation dialog that names the container (or containers) about to be removed, explains the consequence, and requires explicit confirmation. The dialog SHALL have a "Delete" destructive button and a "Cancel" default button. Pressing Escape SHALL cancel. The system SHALL run `docker rm -f` (or `-v` if the user opts to also remove the associated anonymous volume) only after confirmation.

#### Scenario: Delete one container
- **WHEN** the user chooses Delete on a single container row
- **THEN** a confirmation dialog appears: "Delete container `webapp`? This stops and removes the container. Its image and named volumes are preserved."
- **AND** the dialog has Cancel (default) and Delete (destructive) buttons
- **AND** pressing Escape or clicking Cancel closes the dialog without deleting

#### Scenario: Delete three containers
- **WHEN** the user selects three containers in the table and clicks Delete in the contextual action bar
- **THEN** a confirmation dialog appears: "Delete 3 containers? This stops and removes the selected containers."
- **AND** the dialog shows the first three names with an ellipsis if more were selected
- **AND** confirming runs `docker rm -f` for each in sequence

### Requirement: Inspect panel shows container JSON in a structured view
The Inspect action SHALL open an `InspectPanel` (a sheet or a side-pane in the detail area) that renders the container's full `docker inspect` JSON in a structured, navigable view. The panel SHALL show: a top metadata section (Name, Image, ID, Created, State, Status), a Configuration section (Env, Cmd, Entrypoint, WorkingDir, User), a Networking section (Ports, Networks, IP address), a Mounts section (Volumes, Bind mounts, Tmpfs), and a "Raw JSON" disclosure at the bottom. Each value SHALL be selectable and copyable.

#### Scenario: Inspect a container
- **WHEN** the user chooses Inspect on a container row
- **THEN** an Inspect panel appears
- **AND** the panel shows the metadata, configuration, networking, mounts, and raw JSON sections
- **AND** any value can be selected and copied via the standard macOS text selection

#### Scenario: Inspect panel is searchable
- **WHEN** the user presses ⌘F inside the Inspect panel
- **THEN** an in-view search field appears
- **AND** typing a key highlights all matches across the panel's sections
- **AND** Return advances to the next match

### Requirement: Logs view shows a streaming tail of container output
The Logs action SHALL open a Logs view (a sheet or a side-pane) that streams `docker logs --follow --timestamps <container>` output through a `TerminalLogView`. The view SHALL default to "follow" mode, SHALL respect the existing `useStreamingCommandOutput` setting, SHALL show timestamps in the gutter, SHALL auto-scroll to the bottom by default, SHALL show a "Jump to live" affordance when the user scrolls up, and SHALL support search (⌘F), copy-all, and toggle-line-numbers. Closing the panel SHALL cancel the streaming command.

#### Scenario: Open the Logs view
- **WHEN** the user chooses Logs on a running container row
- **THEN** a Logs view appears with a "tailing" indicator in the header
- **AND** new log lines stream in as they are produced
- **AND** the view auto-scrolls to the bottom by default

#### Scenario: Close the Logs view
- **WHEN** the user closes the Logs view
- **THEN** the streaming command is cancelled
- **AND** the row's Logs action is re-enabled

### Requirement: Container lifecycle events update the table
When a container is started, stopped, restarted, or deleted via the UI or via the CLI, the table SHALL update within 500ms via the existing event bus. The update SHALL be a delta (just the affected row) not a full refresh. The row's action availability SHALL update to match the new state without a flash.

#### Scenario: Start a stopped container
- **WHEN** the user starts a stopped container
- **THEN** the row's StateDot animates from grey to green within 500ms
- **AND** the row's available actions switch (Start becomes disabled, Stop and Delete become enabled)
- **AND** no full table reload occurs

### Requirement: Container lifecycle operations are reflected in Activity
Every Start, Stop, Restart, and Delete operation SHALL be recorded as a `CommandLogEntry` in the Activity screen with the appropriate command, status, output, and timing. Failures SHALL include the stderr output in the entry's expandable output.

#### Scenario: Start a container
- **WHEN** the user starts a container
- **THEN** the Activity screen shows a new "Start container `webapp`" entry
- **AND** on success the entry status is `.succeeded` with the docker output
- **AND** on failure the entry status is `.failed` with the stderr
