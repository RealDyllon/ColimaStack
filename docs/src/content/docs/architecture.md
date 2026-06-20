---
title: Architecture
description: How ColimaStack connects the macOS app, Colima CLI, Docker CLI, kubectl, and local Colima files.
---

ColimaStack is a native macOS GUI backed by local command-line tools and file-backed Colima configuration.

## Event-driven control plane

ColimaStack uses a push-based event bus (`RuntimeEventBus`) to deliver state updates from multiple long-lived sources to a central reducer (`AppState.reduce`). This replaces the former fixed-interval polling loop.

### Runtime event sources

- **Docker engine events** (`DockerEventSource`): A long-lived `docker events --format '{{json .}}'` subscription over the selected profile's Docker context. Bootstraps with a full `docker ps/images/volume ls/network ls` snapshot, then applies deltas on engine events. Reconnects with exponential backoff.
- **Kubernetes watch** (`KubernetesWatchSource`): A long-lived `kubectl get pods -A -w -o json` watch. Bootstraps with a full `kubectl get` snapshot per resource kind (nodes, namespaces, pods, services, deployments), then re-snapshots on watch events.
- **Colima file watcher** (`ColimaFileWatcherSource`): `DispatchSource` file-system watchers on `~/.colima/<profile>/colima.yaml`, `daemon/daemon.log`, and the lima instance state. On config/state changes, triggers a single on-demand `colima status --json` probe. Tails the daemon log live from the last-read offset.

### Streaming process runner

`StreamingProcessRunner` yields stdout/stderr chunks via `AsyncStream` as they arrive, without waiting for process exit. This enables:
- Live command output for `colima start/stop/restart/delete/kubernetes/update` in the Activity view
- Long-lived `docker stats` (streaming, no `--no-stream`) for the Monitor view
- Long-lived `kubectl get -w` for Kubernetes watches

### Connection state

Each source tracks a `ConnectionState` (`disconnected`, `connecting`, `connected`, `reconnecting`, `failed`) that is surfaced in the menu bar and Overview screen. Reconnect uses exponential backoff with jitter, capped at 30 seconds.

### Lifecycle

The `RuntimeEventEngine` owns the event bus lifecycle at the application scope (survives main window close). It observes `AppState.selectedProfileID` and starts/stops per-profile sources on change.

## On-demand control plane

The app still calls the Colima CLI directly for profile lifecycle and configuration-oriented operations:

- `colima list --json`
- `colima status --json`
- `colima start`
- `colima stop`
- `colima restart`
- `colima delete`
- `colima update`
- `colima kubernetes start`
- `colima kubernetes stop`
- `colima template`
- `colima ssh-config`
- `colima ssh`

Most profile-scoped operations use the `COLIMA_PROFILE` environment variable.

## Docker inventory

Docker resources are read through the Docker CLI using JSON output where available:

- `docker ps -a --format json`
- `docker images --format json`
- `docker volume ls --format json`
- `docker network ls --format json`
- `docker stats --format json` (streaming)
- `docker system df --format json`
- `docker events --format json` (long-lived stream)

## Kubernetes inventory

Kubernetes resources are read through `kubectl`:

- `kubectl get nodes -o json`
- `kubectl get namespaces -o json`
- `kubectl get pods -A -o json`
- `kubectl get deployments -A -o json`
- `kubectl get services -A -o json`
- `kubectl top nodes`
- `kubectl top pods -A`
- `kubectl get pods -A -w -o json` (long-lived watch)

## File-backed documents

ColimaStack also reads selected files from Colima state:

- profile config: `$COLIMA_HOME/<profile>/colima.yaml`
- template: `$COLIMA_HOME/_templates/default.yaml`
- SSH config: `$COLIMA_HOME/ssh_config`
- daemon log: `$COLIMA_HOME/<profile>/daemon/daemon.log`

File changes are detected via `DispatchSource` vnode sources rather than periodic re-reads.

## Tool presence

Tool presence and version (`colima`, `docker`, `kubectl`, `limactl`) are probed once at startup and on a slow 60-second timer, not on every refresh. Versions are cached for the session.

See [Command API](/reference/command-api/) for the current backend contract.
