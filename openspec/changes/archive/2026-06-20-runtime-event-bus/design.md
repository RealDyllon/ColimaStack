## Context

ColimaStack is a native macOS SwiftUI app that fronts the Colima CLI, Docker CLI, and kubectl. Today `AppState.runAutoRefreshLoop` (`AppState.swift:150`) is a `while !Task.isCancelled` loop that sleeps 2–10s and calls `refreshAll()`, which spawns ~20 subprocesses and re-reads files to produce a fresh `ColimaBackendSnapshot`. There are zero push transports in the codebase (grepped: no `DispatchSource`, `FSEvents`, `AsyncStream`, `NWConnection`, `NotificationCenter` usage for state). Every screen reads from a single `@MainActor` god-object (`AppState`) holding ~22 `@Published` properties, so any change republishes every screen. The loop is started from `ContentView.task` (`ColimaStackApp.swift:20`), so closing the main window kills refreshes and the `MenuBarExtra` goes stale forever. `ProcessRunner` buffers all output to EOF (`ProcessRunner.swift:231-311`), so `colima start` (300s timeout) shows no progress until exit.

Constraints:
- macOS 14+ target (Network framework, DispatchSource, async/await, `AsyncStream` all available).
- No existing specs in `openspec/specs/`; all behavior is greenfield capability.
- Existing `ColimaControlling`/`BackendSnapshotProviding` protocols and their tests must keep working during migration; the polling path stays as a fallback.
- The Docker socket path is already available at runtime (`ColimaStatusDetail.socket`, e.g. `unix:///Users/…/.colima/default/docker.sock`).
- `ProcessCancellation` already exists (`ProcessRunner.swift:129`) and is wired through `AsyncProcessRunnerAdapter` — reuse it.

Stakeholders: end users (responsiveness, battery), maintainers (testability of the refresh path), menu-bar-only users (currently broken on window close).

## Goals / Non-Goals

**Goals:**
- Container, image, volume, network, pod, deployment, and service state updates appear within ~1 second of the underlying change, without polling.
- `colima start`/`stop`/`restart` and `docker stats` stream output live to the Activity/Monitor views.
- The daemon log tails live instead of being re-slurped every tick.
- The menu bar stays accurate after the main window is closed.
- Per-source connection state is explicit and surfaced, so transient failures are visible and recovered with backoff rather than folded into `BackendIssue`.
- Eliminate the ~20-spawns-per-tick cost and the duplicate `colima status` / `docker context show` / `kubectl config current-context` probes.
- Keep the change phased and reversible: each event source lands independently behind a feature flag, with polling retained as fallback.

**Non-Goals:**
- Migrating `AppState` off `ObservableObject`/`@Published` onto the `@Observable` macro. (Follow-up change; would scope-creep this one.)
- Splitting the god-object into per-feature view models. (Follow-up; this change only adds the reducer contract and stops republishing unchanged slices where cheap.)
- Replacing the hand-rolled `ColimaConfigurationParser` with a real YAML parser. (Separate change.)
- Raw apiserver watch HTTP or raw Docker socket HTTP as the primary path. (Start with CLI streaming; revisit as a later optimization.)
- Changing the on-disk Colima file layout or the Colima CLI contract.
- Adding new user-facing screens. (Only connection-state indicators on existing screens.)

## Decisions

### D1. Event bus = `AsyncStream<RuntimeEvent>` fan-in, not Combine, not NotificationCenter
The bus is a single `AsyncStream<RuntimeEvent>` consumed by an `AppState` reducer task. Sources (`AsyncStream` producers) push events in.

**Rationale:** `AsyncStream` is native to structured concurrency, actor-isolatable, backpressure-friendly (buffering policy可控), and avoids the main-actor-republish problem that Combine `PassthroughSubject` would inherit. `NotificationCenter` is untyped and global.

**Alternatives considered:**
- Combine `PassthroughSubject<RuntimeEvent, Never>`: republishes on the main actor by convention; same god-object republish smell; no backpressure.
- `NotificationCenter`: untyped `[Any]` payloads; no structured cancellation.

### D2. Docker events via streaming `docker events --format '{{json .}}'`, not raw socket HTTP
The `docker-event-socket` capability is implemented as a long-lived `docker --context <ctx> events --format '{{json .}}'` process using the new streaming runner (D4), parsing one JSON object per line. The socket path from `ColimaStatusDetail.socket` is used only to know the endpoint exists; the CLI handles HTTP-over-unix-socket.

**Rationale:** Reuses `streaming-process-runner`; avoids implementing HTTP/1.1 chunked encoding over `NWConnection` to a unix socket; the `docker` CLI is already a hard dependency.

**Alternatives considered:**
- Raw `NWConnection` to the unix socket with `GET /events` HTTP: fewer long-lived processes, but requires a custom HTTP-over-socket client and chunked-body parsing. Deferred to a later optimization if process churn is a problem.
- `docker events` without `--format`: plain text, harder to parse reliably.

### D3. Kubernetes watch via `kubectl get -w -o json`, not raw apiserver watch
The `kubernetes-watch` capability runs one `kubectl --context <ctx> get <resource> -A -w -o json` per resource type (nodes, namespaces, pods, services, deployments) using the streaming runner. `kubectl get -w -o json` emits a stream of `{ "type": "ADDED|MODIFIED|DELETED", "object": {…} }` objects, one per line.

**Rationale:** Same as D2 — reuses the streaming runner and the existing `kubectl` dependency; no custom apiserver watch HTTP / kubeconfig TLS client. `kubectl` handles reconnect bookkeeping internally for short drops; for longer drops we restart the watch with a fresh bootstrap snapshot.

**Alternatives considered:**
- Direct apiserver `GET /api/v1/…?watch=true&resourceVersion=…` via `URLSession` websockets or `NWConnection`: more efficient and gives `resourceVersion` bookmarks for resume, but requires kubeconfig parsing + TLS + auth. Defer.
- `kubectl get -w` without `-o json`: plain table output, not delta-friendly.

### D4. New `StreamingProcessRunner` alongside the buffered `LiveProcessRunner`
Add a sibling runner that takes a `ProcessRequest` and returns `(AsyncStream<ProcessChunk>, AsyncThrowingStream<ProcessResult, Error>)` (or a single stream that emits chunks then a terminal result). It forwards stdout/stderr data as it arrives via the existing `readabilityHandler`, cooperates with `ProcessCancellation`, and does **not** wait for EOF to start yielding. The existing buffered `LiveProcessRunner` is untouched (still used by on-demand probes and tests).

**Rationale:** Long-lived `docker events`, `docker stats`, `kubectl get -w`, and one-shot `colima start` all need incremental output. Keeping the buffered path lets the on-demand `colima status`/`list` probes stay simple and their tests unchanged.

**Alternatives considered:**
- Modify `LiveProcessRunner` to optionally stream: complicates the single-shot path and its tests.
- A callback-based API instead of `AsyncStream`: less composable with the bus.

### D5. Colima file watching via `DispatchSource.makeFileSystemObjectSource`
`colima-file-watcher` opens a `FileHandle` on `~/.colima/<profile>/colima.yaml`, `daemon/daemon.log`, and the lima instance state file, and registers a `DispatchSource` vnode source for `.write | .delete | .rename | .extend`. On fire:
- For `colima.yaml` / lima state: trigger a single on-demand `colima status --json` probe (not a full `refreshAll`).
- For `daemon.log`: seek to the last-read offset, read the new bytes, redact, and append to `logs` (coalesced — see D7).

**Rationale:** `DispatchSource` is the standard macOS kernel-level file event primitive; cheaper than `FSEvents` for a small fixed set of files.

**Alternatives considered:**
- `FSEvents`: designed for whole-directory-tree watching; heavier; overkill for 3 files.
- Polling mtime: what we have today; the thing we're removing.

### D6. `AppState` becomes a reducer; polling path retained behind a flag
`AppState` gains `func reduce(_ event: RuntimeEvent)` which applies deltas to `profiles`, `selectedProfileDetail`, `backendSnapshot` (decomposed into docker/k8s sub-state), `logs`, `monitorHistory`, and connection state. It republishes only the `@Published` slice that actually changed (e.g. a container delta updates `backendSnapshot?.docker?.containers` only). `runAutoRefreshLoop` and `refreshGeneration` are removed when the flag is on; a `toolCheckTimer` (60–120s) replaces the per-tick `toolChecks`.

A `UserDefaults` bool `useEventBus` (default off in phase 1, on by phase 3) gates the new path. When off, the app behaves exactly as today.

**Rationale:** Phased, reversible migration; each source can ship independently; tests for the reducer are independent of process/IO.

**Alternatives considered:**
- Big-bang replacement: too risky given no test coverage of the polling lifecycle.
- Separate `EventDrivenAppState` class: duplicates too much; the reducer is just new methods on the existing object.

### D7. Backpressure: coalesce high-frequency events before main-actor publish
Log tail chunks and `docker stats` samples are coalesced in the source before publishing: buffer chunks for ≤50ms (or ≤N bytes) and emit one merged event. `monitorHistory` keeps its 90-sample cap; `logs` keeps its 200KB cap. The reducer never receives unbounded streams.

**Rationale:** A verbose `colima start` or a busy `docker events` stream could otherwise flood the main actor with thousands of publishes/sec.

**Alternatives considered:**
- Drop events on overflow: loses data the user wants to see.
- Unbounded queue: memory growth.

### D8. Event bus lifecycle bound to `ColimaStackApp`, not `ContentView`
The bus is created and started in `ColimaStackApp` (an `@StateObject` `RuntimeEventEngine` alongside `AppState`), not in `ContentView.task`. It subscribes to `appState.selectedProfileID` changes and starts/stops per-profile sources accordingly. Closing the main window does not cancel the bus, so the `MenuBarExtra` stays live.

**Rationale:** Fixes the "menu bar goes stale on window close" defect directly.

**Alternatives considered:**
- A background `NSApplicationDelegate` service: more plumbing; `@StateObject` at the app scope is sufficient.

### D9. Bootstrap-with-snapshot then apply deltas
Docker events and k8s watches do not backfill initial state. On subscribe, each source first runs one `docker ps -a`/`images`/`volume ls`/`network ls` (or `kubectl get -o json`) snapshot, publishes a `SnapshotReplaced` event, then starts the watch and publishes `ItemAdded`/`ItemModified`/`ItemRemoved` deltas. On reconnect after a drop, the same bootstrap runs again before resuming the watch.

**Rationale:** Guarantees a correct full state after (re)connect; deltas alone would only know about changes during the active watch.

**Alternatives considered:**
- Deltas-only with a periodic full reconciliation: brings back polling at a slower cadence; less crisp.

### D10. Explicit per-source `ConnectionState`
Each source exposes a `@Published var connectionState: ConnectionState` (`disconnected`, `connecting`, `connected`, `reconnecting(_ attempt: Int)`, `failed(_ reason: String)`). The reducer rolls these up into a per-profile `RuntimeConnectionStatus` that the UI surfaces (menu bar label + a small status row on Overview). Reconnect uses exponential backoff with jitter, capped at 30s.

**Rationale:** Today every transient failure becomes a `BackendIssue` or overwrites `presentedError`; there is no concept of "we lost the socket and are retrying."

## Risks / Trade-offs

- **Long-lived processes can leak/zombies if not cancelled on profile switch or app exit** → Every source is owned by a `Task` grouped under a `TaskGroup` per profile; profile switch cancels the group; `ProcessCancellation` terminates the child; `AppState`/`RuntimeEventEngine` `deinit` cancels everything. Add a leak-detection unit test.
- **`kubectl get -w` drops on cluster restart mid-watch** → On any stream termination, run the bootstrap snapshot then restart the watch with backoff. A `kubernetes disabled` event stops the watch entirely.
- **`docker events` misses changes during a reconnect gap** → Bootstrap snapshot on reconnect reconciles full state; deltas resume after. Acceptable: worst case is a ~1s blind window during reconnect.
- **Malformed JSON lines from streaming processes** → Drop the line, emit a `BackendIssue` (severity `.warning`, source `.docker`/`.kubernetes`) via the existing malformed-line path; do not crash the stream.
- **Backpressure from verbose log tails** → D7 coalescing; `logs` cap preserved.
- **Larger test surface** → Provide fake `StreamingProcessRunner`, fake `DockerEventSource`, fake `KubernetesWatchSource`, fake `ColimaFileWatcher` test doubles; reducer tests drive synthetic `RuntimeEvent`s with no I/O.
- **Behavioral parity risk during flag-off period** → Keep `refreshAll`/`runAutoRefreshLoop` intact until phase 3; the flag only selects which path drives state. Phase 3 removes the polling code and the flag.
- **`docker events` / `kubectl get -w` not available on older CLI versions** → Probe capability once at startup; fall back to polling for that source if the streaming variant errors. Connection state shows `failed(…)` with a hint.
- **Menu bar + main window both consuming the same `AppState`** → Unchanged from today (both already share the `@StateObject`); the bus just keeps feeding it after window close. No new sharing problem.

## Migration Plan

**Phase 1 — Streaming output (low risk, high UX win):**
1. Add `StreamingProcessRunner` + tests.
2. Route `colima start`/`stop`/`restart`/`delete`/`kubernetes`/`update` command output through it so Activity shows live output.
3. Replace `docker stats --no-stream` with a streaming `docker stats --format '{{json .}}'` per running profile for the Monitor view.
4. Flag: `useStreamingCommandOutput` (default on after validation).

**Phase 2 — Event sources (the core change):**
5. Add `RuntimeEventBus`, `RuntimeEvent` types, reducer scaffolding on `AppState`, and `ConnectionState`.
6. Add `docker-event-socket` source (bootstrap + `docker events` stream → deltas).
7. Add `kubernetes-watch` source (bootstrap + `kubectl get -w` → deltas).
8. Add `colima-file-watcher` source (DispatchSource → status probe + log tail).
9. Bind bus lifecycle to `ColimaStackApp`; start/stop per selected profile.
10. Flag: `useEventBus` (default off). When on, the reducer drives docker/k8s/log state; polling for those concerns is skipped.

**Phase 3 — Remove polling:**
11. With `useEventBus` validated, delete `runAutoRefreshLoop`, `refreshGeneration`, `mergeFreshProfiles`, and the per-tick `docker`/`kubectl` snapshot loaders; keep one slow `toolCheckTimer` (60–120s) for tool presence/version.
12. Remove the flag.

**Rollback:** At any point before phase 3, flip the flag(s) off to restore exact current behavior. Phase 3 deletion is the only irreversible step and happens only after the event path has been the default for a release.

## Open Questions

- Should `AppState` migrate to the `@Observable` macro in this change or a follow-up? **Lean: follow-up**, to keep this change scoped to listening/reducing.
- Raw Docker socket HTTP vs `docker events` CLI process — do we ever need the raw path? Defer to a phase-2 performance review; the CLI process is fine for now.
- `kubectl get -w` vs direct apiserver watch — same; defer.
- Exact `ConnectionState` surface and UI placement (menu bar only? Overview banner? both?) — confirm in design review before phase 2 UI work.
- Whether `toolCheckTimer` should also re-probe on `colima` mtime change (e.g. after a `brew upgrade`) — likely yes; small.
