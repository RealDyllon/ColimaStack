## Why

ColimaStack refreshes its entire view of the world by re-spawning ~20 subprocesses (`colima`, `docker`, `kubectl`) and re-reading files every 2–10 seconds via `AppState.runAutoRefreshLoop`. There is no push transport anywhere in the app — no socket, no file watcher, no streaming process, no event stream. The result is stale-by-design UX: container starts/stops, pod phase transitions, and log lines appear only on the next tick; `colima start` shows a spinner with zero progress for up to 5 minutes because output is buffered to EOF; and the menu bar goes permanently stale the moment the main window closes (the loop is bound to `ContentView.task`). This can never reach the OrbStack-grade responsiveness the project targets while every screen is a snapshot of the last poll.

## What Changes

- Introduce a `RuntimeEventBus` that fans in push events from multiple long-lived sources and feeds them to `AppState`, which becomes a delta-applying reducer instead of a polling orchestrator.
- Add a Docker engine `/events` client over the Colima Docker unix socket (`ColimaStatusDetail.socket`) that streams container/image/volume/network deltas; replace the per-tick `docker ps/images/volume ls/network ls` polls.
- Add a streaming `ProcessRunner` variant that forwards stdout chunks via `AsyncStream` as they arrive (with cancellation), enabling long-lived `docker stats` (drop `--no-stream`) and `kubectl get -w -o json` watches.
- Add Kubernetes watch streams (`kubectl get … -w -o json`, or the apiserver `?watch=true` endpoint) that emit `ADDED`/`MODIFIED`/`DELETED` deltas for nodes/namespaces/pods/services/deployments; replace the six per-tick `kubectl get … -o json` polls.
- Add `DispatchSource` file-system watchers on `~/.colima/<profile>/colima.yaml`, `daemon/daemon.log`, and the lima instance state file; use mtime/size changes to trigger a single on-demand `colima status --json` probe and to tail the daemon log live.
- Remove `runAutoRefreshLoop` and the `refreshGeneration` race-guard machinery; replace with event-driven refresh and a slow (60–120s) fallback timer only for tool-presence/version checks.
- Collapse the duplicate per-tick probes: `colima status`, `docker context show`, and `kubectl config current-context` each currently run twice per refresh (diagnostics + resource service); run them once per session/profile-switch and reuse.
- Introduce an explicit connection-state model (`connected`/`disconnected`/`degraded` per source) so the UI can crisply transition when a socket is lost, instead of folding every transient failure into `BackendIssue`/`presentedError`.

## Capabilities

### New Capabilities
- `runtime-event-bus`: Central fan-in of push events from Docker, Kubernetes, and Colima file sources; defines the `RuntimeEvent` contract, per-profile source lifecycle (start/stop/reconnect with backoff), connection-state tracking, and the reducer contract `AppState` implements to apply deltas.
- `docker-event-socket`: Long-lived subscription to the Docker engine `/events` endpoint over the Colima Docker unix socket; translates engine events into container/image/volume/network delta events; handles socket-gone and reconnect.
- `streaming-process-runner`: A streaming variant of `ProcessRunner` that yields stdout/stderr chunks via `AsyncStream` as they arrive, with cooperative cancellation and no EOF-blocking; enables streaming `docker stats` and `kubectl get -w`.
- `kubernetes-watch`: Per-resource `kubectl get -w -o json` (or apiserver watch) streams that emit `ADDED`/`MODIFIED`/`DELETED` deltas for nodes, namespaces, pods, services, and deployments; replaces the per-tick `kubectl get … -o json` polls.
- `colima-file-watcher`: `DispatchSource` file-system watchers on Colima profile files (`colima.yaml`, `daemon/daemon.log`, lima state) that trigger on-demand `colima status` probes and live tail the daemon log; replaces whole-file re-slurps each tick.

### Modified Capabilities
<!-- No existing specs in openspec/specs/. All behavior is introduced as new capabilities. -->

## Impact

- **Affected code**: `AppState.swift` (becomes a reducer; loses `runAutoRefreshLoop`, `refreshGeneration`, `mergeFreshProfiles`); `Services/ProcessRunner.swift` (adds streaming variant alongside the buffered one); `Services/ColimaCLI.swift` (diagnostics no longer runs every tick; status becomes on-demand/file-event-triggered); `Services/DockerResourceService.swift` and `KubernetesResourceService.swift` (snapshot loaders become delta appliers fed by streams); `Models/ColimaStackApp.swift` (event bus lifecycle bound to the app, not the main window, so the menu bar stays live); new `Services/` modules for each event source.
- **New dependencies**: a YAML parser is out of scope here but the hand-rolled `ColimaConfigurationParser` continues to be used; no new third-party packages strictly required (Network framework + DispatchSource + Process are all system APIs). Optionally Yams later.
- **APIs**: No public API change; the `ColimaControlling`/`BackendSnapshotProviding` protocols gain stream-producing siblings but the existing methods remain for the on-demand probe path.
- **Tests**: New unit tests for each event source (fake socket, fake streaming process, fake file watcher) and for the reducer applying deltas; existing `AppState` refresh tests are refactored to drive the reducer with synthetic events instead of calling `refreshAll`.
- **Performance**: Eliminates ~20 process spawns per tick; container/pod transitions become near-instant; `colima start` gets live streamed output. CPU/battery on idle machines drops substantially.
- **Risk**: Large architectural change. Phased behind the new event sources with the polling path retained as a fallback during migration; each source lands independently and can be feature-flagged.
