## Context

`DockerResourceService` currently spawns 7 child processes per snapshot using the `docker` CLI. The bottleneck is `docker stats --no-stream`, which takes 1–2s because the CLI collects two cgroup samples to compute a delta. All 7 calls run concurrently but each pays process-spawn overhead (~30–100ms on macOS).

The Docker Engine HTTP API is exposed over a Unix domain socket at the path already parsed from `colima status` into `profile.socket`. Switching to direct socket communication eliminates spawn overhead, enables per-container stat queries to run truly concurrently, and opens the door to event-driven invalidation in the future.

The existing `DockerResourceProviding` protocol and `DockerResourceSnapshot` model are kept unchanged as the public contract. Only the implementation layer changes.

## Goals / Non-Goals

**Goals:**
- Replace `LiveDockerResourceService` with `SocketDockerResourceService` implementing `DockerResourceProviding`
- Add a minimal UDS HTTP/1.1 client using `Network.framework` — no new package dependencies
- Fetch all resource types concurrently via the Engine API
- Compute CPU/memory percentages from raw Engine API stats fields (the CLI did this for us; the API does not)
- Update `BackendAggregationService` to pass `profile.socket` instead of a context string

**Non-Goals:**
- Remote Docker contexts (TCP/TLS endpoints) — Colima is always local
- Event streaming (`/events`) — out of scope; polling is retained
- Keeping `LiveDockerResourceService` as a fallback — it is removed

## Decisions

### 1. UDS HTTP client: `Network.framework` `NWConnection` over a custom URLSession approach

`URLSession` does not support Unix domain socket endpoints without undocumented private API. `NWConnection` in `Network.framework` has first-class `UnixSocket` endpoint support and is already available on macOS. A thin wrapper sends a raw HTTP/1.1 GET request and reads the response, handling chunked transfer encoding (Docker uses it for some endpoints).

Alternative considered: import `AsyncHTTPClient` (SwiftNIO-based). Rejected — introduces a heavy dependency for one use case; the API surface we need is two GET patterns.

### 2. Protocol signature: replace `context: String?` with `socketPath: String`

The context string was only used to pass `--context` to the CLI. The socket path is a cleaner, more direct parameter. `BackendAggregationService:289` already has `profile.socket`; it will pass it directly.

The protocol becomes:
```swift
protocol DockerResourceProviding {
    func loadSnapshot(socketPath: String) async -> ResourceLoadState<DockerResourceSnapshot>
    func snapshot(socketPath: String) async throws -> DockerResourceSnapshot
}
```

Alternative: keep `context: String?` and resolve the socket path inside the service via a colima CLI call. Rejected — adds latency and a process spawn back into the hot path.

### 3. Stats: per-container concurrent `GET /containers/{id}/stats?stream=false`

The Engine API does not have a single "all container stats" endpoint. We fire one request per running container in parallel (Swift structured concurrency `async let` / `withTaskGroup`). Each call returns raw cgroup data; we compute the percentage locally:

```
cpu_delta    = cpu_usage.total_usage − precpu_usage.total_usage
system_delta = system_cpu_usage − precpu_system_cpu_usage
cpu_pct      = (cpu_delta / system_delta) × num_cpus × 100
mem_pct      = memory_stats.usage / memory_stats.limit × 100
```

Alternative: keep `docker stats` CLI for just this call. Rejected — this was the primary source of lag; the point of the migration is to fix it.

### 4. Model mapping strategy: thin adapter functions, same output types

All existing `DockerResourceSnapshot` child types (`DockerContainerResource`, `DockerImageResource`, etc.) remain unchanged. The new service adds adapter functions that translate Engine API JSON shapes to these types. Key differences to bridge:

| Resource | CLI shape | Engine API shape |
|---|---|---|
| Container names | `"api"` string | `["/api"]` array, strip leading `/` |
| Container ports | `"0.0.0.0:8080->80/tcp"` string | Array of `{IP, PrivatePort, PublicPort, Type}` objects |
| Image repo/tag | Separate `Repository`, `Tag` fields | `RepoTags: ["nginx:latest"]` array |
| Image digest | `Digest` field | `RepoDigests: ["nginx@sha256:..."]` array |
| Image created | `CreatedAt` human string | `Created` Unix timestamp (Int) |
| Disk usage | Flat JSON lines | Nested `{Images:[],Containers:[],Volumes:[],BuildCache:[]}` |
| Stats | Pre-computed `"1.25%"` strings | Raw cgroup counters; compute locally |

### 5. Active context: removed

`docker context show` was the only call that didn't fetch resources. The context name was stored in `DockerResourceSnapshot.context`. With the socket approach, the Colima profile name is the meaningful identifier. `snapshot.context` will be populated from the socket path (e.g., extract profile name from `~/.colima/<profile>/docker.sock`).

## Risks / Trade-offs

- **Stats concurrency burst** → If there are many containers, N concurrent stat requests hit the daemon simultaneously. Mitigation: cap concurrency with a `TaskGroup` limited to 8 concurrent stats requests.
- **Chunked transfer encoding** → Docker uses chunked encoding on `/containers/{id}/stats`. The UDS client must handle this correctly or response parsing will fail silently. Mitigation: implement a proper chunked decoder in the HTTP client; add a test with a chunked fixture.
- **Socket path unavailable** → If Colima isn't running, `profile.socket` is empty. `SocketDockerResourceService.loadSnapshot` returns `.failed(...)` (same behavior as today when the CLI can't connect). Mitigation: guard on empty socket path before attempting connection.
- **Network.framework availability** → Available on macOS 10.14+; this app targets macOS 13+. No issue.

## Migration Plan

1. Add `DockerUDSClient` — the UDS HTTP client — with no changes to existing code
2. Add `SocketDockerResourceService` implementing `DockerResourceProviding`
3. Update `DockerResourceProviding` protocol signature (`socketPath:`)
4. Update `LiveBackendSnapshotService` call site in `BackendAggregationService`
5. Delete `LiveDockerResourceService`
6. Replace `DockerResourceServiceTests` with socket-based fixtures

No data migration or deployment steps needed — this is entirely in-process.

**Rollback:** revert the PR; `LiveDockerResourceService` is in git history.

## Open Questions

- Should `DockerResourceSnapshot.context` be renamed to `profile` to reflect that it no longer holds a Docker context name? Deferring — a rename is a separate cleanup.
- Should the UDS client be shared with a future Kubernetes socket client, or stay Docker-specific? Deferring — keep it Docker-specific for now.
