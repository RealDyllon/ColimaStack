## Why

`DockerResourceService` shells out to the `docker` CLI for every snapshot — 7 child processes per refresh, including `docker stats --no-stream` which takes 1–2s server-side because the CLI polls cgroups twice. This makes the UI feel laggy and unresponsive. Switching to the Docker Engine HTTP API over the Unix domain socket eliminates process spawn overhead and enables concurrent, event-driven data fetching.

## What Changes

- Replace `LiveDockerResourceService` with a new `SocketDockerResourceService` that communicates with the Docker Engine API via HTTP/1.1 over the Colima Unix domain socket.
- Add a lightweight UDS HTTP client using `Network.framework` (`NWConnection`) — no new package dependencies.
- Map Docker Engine API JSON responses to the existing `DockerResourceSnapshot` model (containers, images, volumes, networks, stats, disk usage).
- Pass the socket path (already parsed from `colima status` into `profile.socket`) to the service instead of a context name string.
- Remove the `docker context show` CLI call — the active context is already known from Colima state.
- Keep `LiveCommandRunService` and `ProcessRunner` in place for Colima CLI and kubectl calls.

## Capabilities

### New Capabilities

- `docker-engine-api-client`: Thin HTTP/1.1 client that sends requests to and parses responses from the Docker Engine API over a Unix domain socket. Supports GET requests and JSON response decoding.
- `docker-socket-resource-service`: Implementation of `DockerResourceProviding` that uses the Docker Engine API client to fetch containers, images, volumes, networks, stats, and disk usage concurrently.

### Modified Capabilities

<!-- No existing specs to modify — this is a new implementation of an existing protocol -->

## Impact

- **Replaces**: `LiveDockerResourceService` (CLI-based) → `SocketDockerResourceService` (socket-based)
- **Call site**: `BackendAggregationService.swift:289` — signature changes from `context: String?` to `socketPath: String`
- **Models**: `DockerResourceSnapshot` and all child models are unchanged; only the field-mapping logic in the service changes
- **Tests**: `DockerResourceServiceTests.swift` — CLI-format fixtures replaced with Engine API JSON fixtures; mock HTTP client replaces mock command runner
- **Dependencies**: No new Swift packages; uses `Network.framework` (already available on macOS)
- **Limitations**: Local Colima sockets only; remote Docker contexts (TCP/TLS) are not supported by this implementation
