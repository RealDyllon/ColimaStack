# streaming-process-runner Specification

## Purpose
TBD - created by archiving change runtime-event-bus. Update Purpose after archive.
## Requirements
### Requirement: Stream stdout and stderr chunks as they arrive
The system SHALL provide a `StreamingProcessRunner` that yields stdout and stderr chunks via an `AsyncStream`/`AsyncThrowingStream` as the data arrives from the child process, WITHOUT waiting for process exit. Each chunk SHALL carry a stream discriminator (`.stdout`/`.stderr`) and the raw `Data`.

#### Scenario: Output appears before process exit
- **WHEN** a long-running child process writes a line to stdout and continues running
- **THEN** the stream yields that line as a chunk before the process exits

#### Scenario: Both streams are distinguishable
- **WHEN** a child writes to stdout and stderr
- **THEN** the consumer can tell which chunks came from stdout and which from stderr

### Requirement: Provide a terminal result with exit status
The system SHALL emit a terminal `ProcessResult` (or equivalent) carrying the termination status, total duration, and any truncated-output flags after the child exits. The terminal result SHALL be the last value produced by the stream before it completes.

#### Scenario: Exit status is available after exit
- **WHEN** a child process exits with status 0
- **THEN** the stream emits a terminal result with `terminationStatus == 0` and then completes

#### Scenario: Non-zero exit is reported
- **WHEN** a child process exits with status 1
- **THEN** the terminal result carries `terminationStatus == 1`

### Requirement: Support cooperative cancellation
The system SHALL support cooperative cancellation via `ProcessCancellation` (and Swift structured cancellation). When cancellation is requested, the runner SHALL terminate the child process (escalating terminate → interrupt → SIGKILL as the existing `ProcessCancellation` does) and complete the stream with a `CancellationError`.

#### Scenario: Cancellation terminates the child
- **WHEN** the consuming `Task` is cancelled while a child is running
- **THEN** the child process is terminated and the stream throws a `CancellationError`

#### Scenario: Cancellation escalates to SIGKILL
- **WHEN** the child does not respond to `terminate()` within the existing escalation deadlines
- **THEN** the runner escalates to `interrupt()` then `kill(SIGKILL)` per the existing `ProcessCancellation` behavior

### Requirement: Respect timeout for long-running processes
The system SHALL enforce the `ProcessRequest.timeout` by cancelling the child when the timeout elapses and completing the stream with a `ProcessRunnerError.timedOut`. The timeout SHALL NOT require the consumer to have read all chunks.

#### Scenario: Timeout cancels the child
- **WHEN** a child runs longer than its request's timeout
- **THEN** the child is terminated and the stream throws `ProcessRunnerError.timedOut`

### Requirement: Do not block the buffered single-shot runner
The system SHALL implement the streaming runner as a new type alongside the existing buffered `LiveProcessRunner`. The existing buffered runner, its API, and its tests SHALL remain unchanged and SHALL continue to be used for on-demand probes (e.g. `colima status`, `colima list`).

#### Scenario: Buffered runner is unaffected
- **WHEN** the streaming runner is added
- **THEN** `LiveProcessRunner.run(_:)` still returns a complete `ProcessResult` after `waitUntilExit` and existing `ProcessRunnerTests` pass without modification

### Requirement: Redact secrets in chunked output
The system SHALL apply `EnvironmentRedactor.redacted` to stdout/stderr chunks before yielding them when the chunk is destined for user-facing display or command-log storage, consistent with the existing redaction applied by `LiveCommandRunService`.

#### Scenario: A secret in streamed output is redacted
- **WHEN** a streamed stdout chunk contains `TOKEN=abc123`
- **THEN** the yielded/redacted chunk contains `TOKEN=<redacted>` and not `abc123`

