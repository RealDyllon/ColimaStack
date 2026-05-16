## 1. UDS HTTP Client

- [x] 1.1 Create `DockerUDSClient.swift` — `nonisolated struct` with `socketPath: String` and `timeout: TimeInterval`
- [x] 1.2 Implement `NWConnection` setup for `UnixSocket` endpoint using `Network.framework`
- [x] 1.3 Implement HTTP/1.1 GET request builder (request line, Host header, Connection: close)
- [x] 1.4 Implement response reader: parse status line, headers, and body (Content-Length and chunked transfer encoding)
- [x] 1.5 Implement chunked body reassembly (parse chunk size hex, accumulate chunks, detect terminal `0\r\n\r\n`)
- [x] 1.6 Throw descriptive errors for: connection failure, timeout, non-2xx status, invalid UTF-8 response

## 2. Docker Socket Resource Service

- [x] 2.1 Create `SocketDockerResourceService.swift` implementing `DockerResourceProviding` with `socketPath: String` parameter
- [x] 2.2 Implement `snapshot(socketPath:)` — fires concurrent `async let` requests for containers, images, volumes, networks, disk usage
- [x] 2.3 Add `GET /containers/json?all=1` → map to `[DockerContainerResource]`
- [x] 2.4 Add container field adapters: strip leading `/` from names, parse `Ports` object array into `portBindings`, parse `Labels` object
- [x] 2.5 Add `GET /images/json?digests=1` → split `RepoTags[0]` into repository/tag, extract digest from `RepoDigests[0]`, format `Created` Unix timestamp
- [x] 2.6 Add `GET /volumes` → map `Volumes` array to `[DockerVolumeResource]`
- [x] 2.7 Add `GET /networks` → map to `[DockerNetworkResource]`
- [x] 2.8 Add `GET /system/df` → map nested sections (Images, Containers, Volumes, BuildCache) to `[DockerDiskUsageResource]`
- [x] 2.9 Implement per-container stats fetch: `GET /containers/{id}/stats?stream=false` for each running container, capped at 8 concurrent requests via `withTaskGroup`
- [x] 2.10 Implement CPU % calculation: `(cpu_delta / system_delta) × online_cpus × 100`; guard against zero system delta
- [x] 2.11 Implement memory % calculation: `(usage / limit) × 100`; format as `"X.XX%"` string
- [x] 2.12 Implement context name derivation from socket path (`default` → `"colima"`, `<profile>` → `"colima-<profile>"`)
- [x] 2.13 Return partial snapshot with `BackendIssue` entries when individual section requests fail

## 3. Protocol and Call Site Updates

- [x] 3.1 Update `DockerResourceProviding` protocol: replace `context: String?` with `socketPath: String` in both `loadSnapshot` and `snapshot`
- [x] 3.2 Update `LiveBackendSnapshotService.loadDockerSnapshot` in `BackendAggregationService.swift` to pass `profile.socket` instead of a context string
- [x] 3.3 Delete `LiveDockerResourceService` from `DockerResourceService.swift`

## 4. Tests

- [x] 4.1 Add `DockerUDSClientTests.swift` — mock `NWConnection` or test against a local echo server; cover: success, non-2xx, timeout, chunked encoding
- [x] 4.2 Replace `DockerResourceServiceTests.swift` with `SocketDockerResourceServiceTests.swift` using a mock `DockerUDSClient` protocol
- [x] 4.3 Add test: containers — names strip slash, ports parse from object array, labels from object
- [x] 4.4 Add test: images — RepoTags split, digest extracted, Created timestamp formatted
- [x] 4.5 Add test: stats — CPU % and memory % computed correctly from raw counters; zero system delta returns `"0.00%"`
- [x] 4.6 Add test: partial failure — one section errors, other sections still populated, issues array has one entry
- [x] 4.7 Add test: context name derivation from socket path (default and named profile)
- [x] 4.8 Add test: empty socket path returns `.failed(...)` without attempting connection

## 5. Cleanup

- [x] 5.1 Remove `docker context show` CLI call from any remaining code paths
- [x] 5.2 Verify `ToolLocator` / `CommandRunService` are no longer imported by `DockerResourceService.swift`
- [x] 5.3 Build and run all tests; confirm no regressions in `AppStateBackendAggregationTests` or `BackendSearchIndexTests`
