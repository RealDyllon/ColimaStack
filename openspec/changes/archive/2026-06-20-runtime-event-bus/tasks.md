## 1. Foundation types and streaming runner

- [x] 1.1 Define `RuntimeEvent` enum with `source` (`.docker`, `.kubernetes`, `.colima`, `.command`) and typed payloads (`SnapshotReplaced`, `ItemAdded`, `ItemModified`, `ItemRemoved`, `ColimaStatusUpdated`, `LogAppended`, `StatsSample`, `ConnectionStateChanged`) in a new `Services/RuntimeEventBus.swift`
- [x] 1.2 Define `ConnectionState` enum (`disconnected`, `connecting`, `connected`, `reconnecting(_ attempt: Int)`, `failed(_ reason: String)`) and `RuntimeConnectionStatus` aggregate in `Services/RuntimeEventBus.swift`
- [x] 1.3 Implement `StreamingProcessRunner` in a new `Services/StreamingProcessRunner.swift` that yields `ProcessChunk` (`.stdout(Data)`/`.stderr(Data)`) via `AsyncStream` then a terminal `ProcessResult`, reusing `ProcessCancellation` for cooperative cancellation and `ProcessOutputBuffer` for truncation
- [x] 1.4 Add a redaction pass for streamed chunks destined for display/log storage, reusing `EnvironmentRedactor.redacted`
- [x] 1.5 Add `StreamingProcessRunnerTests` covering: chunks arrive before exit, terminal result exit status (0 and non-zero), cooperative cancellation escalates terminate→interrupt→SIGKILL, timeout throws `ProcessRunnerError.timedOut`, malformed/secret content is redacted
- [x] 1.6 Verify existing `LiveProcessRunner` and `ProcessRunnerTests` are unchanged and pass

## 2. Phase 1 — Streaming command output

- [x] 2.1 Add `useStreamingCommandOutput` flag (UserDefaults, default on) read in `AppState`
- [x] 2.2 Route `colima start`/`stop`/`restart`/`delete`/`kubernetes`/`update` command output through `StreamingProcessRunner` so `commandLog` entries update incrementally as chunks arrive (replace the buffered `runCommand` path for these lifecycle commands)
- [x] 2.3 Surface live command output in the Activity screen `CommandEntryRow` (append chunks to the running entry's `output` until terminal, then set final status)
- [x] 2.4 Replace `docker stats --no-stream` in `DockerResourceService` with a long-lived streaming `docker stats --format '{{json .}}'` per running profile, parsing one JSON line per chunk and publishing `StatsSample` events
- [x] 2.5 Add a Cancel control to the toolbar when `activeOperation != nil` that cancels the running command's `Task` (and its `ProcessCancellation`)
- [x] 2.6 Add tests: streaming command log appends chunks; cancel terminates the process; streaming stats update `monitorHistory` per sample

## 3. Phase 2 — Event bus and reducer scaffolding

- [x] 3.1 Implement `RuntimeEventBus` as an `AsyncStream<RuntimeEvent>` fan-in with per-source `Continuation` registration and a bounded buffer
- [x] 3.2 Add `RuntimeEventEngine` `@StateObject` in `ColimaStackApp` (alongside `AppState`) that owns the bus lifecycle, started at app launch (NOT in `ContentView.task`), and survives main window close
- [x] 3.3 Add `useEventBus` flag (UserDefaults, default off) gating the event-driven path
- [x] 3.4 Add `AppState.reduce(_ event: RuntimeEvent)` that applies deltas to the minimal affected `@Published` slice (docker containers/images/volumes/networks, k8s nodes/namespaces/pods/services/deployments, `logs`, `monitorHistory`, `selectedProfileDetail`, connection status) WITHOUT spawning subprocesses
- [x] 3.5 Make `RuntimeEventEngine` observe `appState.selectedProfileID` and start/stop per-profile sources on change (cancel previous profile's `TaskGroup` before starting new)
- [x] 3.6 Replace the per-tick `toolChecks` with a slow `toolCheckTimer` (60s) + startup probe, caching versions for the session
- [x] 3.7 Add reducer unit tests driving `AppState.reduce` with synthetic `RuntimeEvent`s (no I/O): container modified updates only that container; pod removed removes only that pod; `SnapshotReplaced` replaces the slice; `LogAppended` appends without re-reading; `ConnectionStateChanged` updates connection status
- [x] 3.8 Add a connection-status indicator to the menu bar label/Overview showing per-source `ConnectionState`

## 4. Phase 2 — Docker event source

- [x] 4.1 Implement `DockerEventSource` in `Services/DockerEventSource.swift` that bootstraps with `docker ps -a`/`images`/`volume ls`/`network ls` snapshots then runs a long-lived `docker --context <ctx> events --format '{{json .}}'` via `StreamingProcessRunner`
- [x] 4.2 Translate each `docker events` JSON line to a typed `RuntimeEvent` (`ItemAdded`/`ItemModified`/`ItemRemoved` keyed by container/image/volume/network) using the same field mapping as `DockerResourceService`'s parsers
- [x] 4.3 Skip the source for non-`.docker` runtimes (set docker `connectionState` to `disconnected` with "not Docker" reason)
- [x] 4.4 Implement reconnect with exponential backoff + jitter (cap 30s), re-bootstrapping the snapshot before resuming deltas
- [x] 4.5 Stop the source on profile switch or profile `.stopped` (terminate the streaming process, release resources)
- [x] 4.6 Drop malformed JSON lines and publish a `.warning` `BackendIssue` (source `.docker`) without crashing the stream
- [x] 4.7 Add `DockerEventSourceTests` with a fake `StreamingProcessRunner`: bootstrap-then-delta ordering, container added/modified/removed deltas, non-docker skip, reconnect re-bootstraps, malformed line dropped with warning, profile switch stops the stream

## 5. Phase 2 — Kubernetes watch source

- [x] 5.1 Implement `KubernetesWatchSource` in `Services/KubernetesWatchSource.swift` running one `kubectl --context <ctx> get <resource> -A -w -o json` per resource kind (nodes, namespaces, pods, services, deployments) via `StreamingProcessRunner`
- [x] 5.2 Bootstrap each resource with one `kubectl get <resource> -A -o json` snapshot (`SnapshotReplaced`) before applying watch deltas
- [x] 5.3 Parse each watch line `{ "type": "ADDED|MODIFIED|DELETED", "object": {…} }` into a typed `RuntimeEvent` using the same field mapping as `KubernetesResourceService`'s parsers
- [x] 5.4 Do not start watches when `kubernetes.enabled == false` (set kubernetes `connectionState` to `disconnected` with "Kubernetes disabled" reason)
- [x] 5.5 Reconnect dropped watches with backoff, re-bootstrapping the snapshot first; stop watches on profile switch or kubernetes disable
- [x] 5.6 Drop malformed watch JSON lines and publish a `.warning` `BackendIssue` (source `.kubernetes`)
- [x] 5.7 Add `KubernetesWatchSourceTests` with a fake `StreamingProcessRunner`: bootstrap-then-delta per resource, pod phase change → modified delta, pod delete → removed delta, kubernetes-disabled skip, reconnect re-bootstraps, malformed line dropped, profile switch stops all watches

## 6. Phase 2 — Colima file watcher source

- [x] 6.1 Implement `ColimaFileWatcherSource` in `Services/ColimaFileWatcherSource.swift` registering `DispatchSource.makeFileSystemObjectSource` (`.write | .delete | .rename | .extend`) on `colima.yaml`, `daemon/daemon.log`, and the lima instance state file for the selected profile
- [x] 6.2 On `colima.yaml`/lima-state change, trigger a single on-demand `colima status --json` probe and publish `ColimaStatusUpdated` (no `refreshAll`, no tool version probes)
- [x] 6.3 Tail `daemon.log` from the last-consumed offset on each change; redact new bytes; publish `LogAppended`; handle truncation/rotation by resetting offset to 0
- [x] 6.4 Coalesce rapid `daemon.log` growth (≤50ms window) into one `LogAppended` event
- [x] 6.5 Handle missing files: poll for appearance at a short interval, set `connectionState` to `connecting` until the file exists, then `connected`
- [x] 6.6 Stop and release all `DispatchSource`s and `FileHandle`s on profile switch before starting new-profile watchers
- [x] 6.7 Add `ColimaFileWatcherSourceTests` with a temp-dir fake: colima.yaml change triggers one status probe; daemon.log append publishes only new bytes; truncation resets offset; missing file does not crash; profile switch releases handles (verify via leak/double-free guard)

## 7. Phase 2 — Wire-up and fallback removal for event-driven concerns

- [x] 7.1 When `useEventBus` is on, skip the docker/k8s snapshot-loading portions of `refreshAll` and let the reducer drive those slices; keep `refreshAll` only for the on-demand probe path triggered by file events
- [x] 7.2 Collapse duplicate per-tick probes: `colima status`, `docker context show`, `kubectl config current-context` each run at most once per session/profile-switch and are cached/reused by all sources
- [x] 7.3 Ensure the `MenuBarExtra` reflects live state after main window close (verify the bus keeps running; add a UI test that closes the window and checks the menu bar still updates on a synthetic event)
- [x] 7.4 Add an end-to-end integration test (fake sources) driving a profile switch through the bus and asserting old-profile sources cancel and new-profile sources bootstrap

## 8. Phase 3 — Remove polling

- [x] 8.1 Flip `useEventBus` default to on after phase 2 validation
- [x] 8.2 Delete `runAutoRefreshLoop`, `refreshGeneration`, and `mergeFreshProfiles` from `AppState`; remove the loop start from `ColimaStackApp`
- [x] 8.3 Remove the per-tick `docker ps/images/volume ls/network ls` and `kubectl get -o json` snapshot loaders from `DockerResourceService`/`KubernetesResourceService` (retaining only the bootstrap snapshot methods used by the sources)
- [x] 8.4 Remove the `useEventBus` and `useStreamingCommandOutput` flags and the dead `appState.searchText` published property
- [x] 8.5 Remove the `runAutoRefreshLoop`-related tests and update `AppStateTests`/`AppStateBackendAggregationTests` to drive state via the reducer instead of `refreshAll`
- [x] 8.6 Update `docs/src/content/docs/architecture.md` to document the event-driven control plane (Docker events, kubectl watch, DispatchSource file watchers) replacing the polling loop

## 9. Cross-cutting verification

- [x] 9.1 Run `swift test` (or `xcodebuild test`) and confirm all unit tests pass
- [x] 9.2 Run the UI tests (`ColimaStackUITests`) and confirm no regressions; add a UI test for live command output streaming and menu-bar-stays-live-on-window-close
- [x] 9.3 Manually verify: container start/stop appears in the Containers screen within ~1s without pressing Refresh; `colima start` streams output live; the daemon log tails live; closing the window leaves the menu bar accurate
- [x] 9.4 Verify no zombie/leaked processes after repeated profile switches and app exit (check `ps` / Activity Monitor)
- [x] 9.5 Verify battery/CPU impact on an idle machine is materially lower than the polling baseline (no ~20-spawns-per-tick)
