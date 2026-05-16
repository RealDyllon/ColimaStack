## ADDED Requirements

### Requirement: Implement DockerResourceProviding via Unix socket
`SocketDockerResourceService` SHALL implement the `DockerResourceProviding` protocol, accepting a `socketPath: String` parameter instead of a Docker context name.

#### Scenario: Successful snapshot with running containers
- **WHEN** `snapshot(socketPath:)` is called with a valid Colima socket path
- **THEN** it returns a fully populated `DockerResourceSnapshot` with containers, images, volumes, networks, stats, and disk usage

#### Scenario: Empty socket path
- **WHEN** `loadSnapshot(socketPath:)` is called with an empty string
- **THEN** it returns `.failed(...)` with a descriptive issue and does not attempt a connection

### Requirement: Fetch all resource types concurrently
The service SHALL issue all Engine API requests concurrently using Swift structured concurrency, not sequentially.

#### Scenario: Concurrent fetch
- **WHEN** `snapshot(socketPath:)` is called
- **THEN** requests for containers, images, volumes, networks, and disk usage are all in-flight simultaneously

### Requirement: Fetch container stats concurrently per container
The service SHALL fetch stats for each running container individually via `GET /containers/{id}/stats?stream=false`, with all per-container requests running concurrently, capped at a maximum of 8 concurrent stat requests.

#### Scenario: Multiple running containers
- **WHEN** there are N running containers
- **THEN** up to 8 stat requests are in-flight at a time; all N results are collected before the snapshot is returned

#### Scenario: No running containers
- **WHEN** no containers are in the running state
- **THEN** no stat requests are made and `snapshot.stats` is empty

### Requirement: Map Engine API container fields to DockerContainerResource
The service SHALL translate Docker Engine API container JSON to `DockerContainerResource`, handling API-specific field shapes.

#### Scenario: Container names strip leading slash
- **WHEN** the Engine API returns `Names: ["/api"]`
- **THEN** `DockerContainerResource.name` is `"api"` (no leading `/`)

#### Scenario: Container ports parsed from object array
- **WHEN** the Engine API returns `Ports: [{IP, PrivatePort, PublicPort, Type}]`
- **THEN** `DockerContainerResource.portBindings` contains the correct `PortBinding` values

#### Scenario: Container labels parsed from object
- **WHEN** the Engine API returns `Labels: {"tier": "backend"}`
- **THEN** `DockerContainerResource.labels` equals `["tier": "backend"]`

### Requirement: Map Engine API image fields to DockerImageResource
The service SHALL translate Docker Engine API image JSON to `DockerImageResource`.

#### Scenario: Repository and tag split from RepoTags
- **WHEN** the Engine API returns `RepoTags: ["nginx:latest"]`
- **THEN** `DockerImageResource.repository` is `"nginx"` and `.tag` is `"latest"`

#### Scenario: Digest extracted from RepoDigests
- **WHEN** the Engine API returns `RepoDigests: ["nginx@sha256:abc"]`
- **THEN** `DockerImageResource.digest` is `"sha256:abc"`

#### Scenario: Created timestamp formatted as string
- **WHEN** the Engine API returns `Created: 1700000000` (Unix timestamp)
- **THEN** `DockerImageResource.createdAt` is a human-readable date string

### Requirement: Compute CPU and memory percentages from raw stats
The service SHALL compute CPU usage percentage and memory usage percentage from the raw cgroup counter fields returned by `GET /containers/{id}/stats?stream=false`.

#### Scenario: CPU percentage calculation
- **WHEN** stats contain `cpu_stats.cpu_usage.total_usage`, `precpu_stats.cpu_usage.total_usage`, `cpu_stats.system_cpu_usage`, `precpu_stats.system_cpu_usage`, and `cpu_stats.online_cpus`
- **THEN** CPU percent equals `(cpu_delta / system_delta) × online_cpus × 100`, formatted to two decimal places with a `%` suffix

#### Scenario: Memory percentage calculation
- **WHEN** stats contain `memory_stats.usage` and `memory_stats.limit`
- **THEN** memory percent equals `(usage / limit) × 100`, formatted to two decimal places with a `%` suffix

#### Scenario: Zero system delta (no change between samples)
- **WHEN** `cpu_stats.system_cpu_usage` equals `precpu_stats.system_cpu_usage`
- **THEN** CPU percent is reported as `"0.00%"` without dividing by zero

### Requirement: Map Engine API disk usage to DockerDiskUsageResource
The service SHALL translate the nested `GET /system/df` response to the flat `[DockerDiskUsageResource]` format.

#### Scenario: Disk usage sections present
- **WHEN** the Engine API returns `{Images:[...], Containers:[...], Volumes:[...], BuildCache:[...]}`
- **THEN** each section produces one `DockerDiskUsageResource` entry with `type`, `totalCount`, `size`, and `reclaimable`

### Requirement: Populate snapshot issues for partial failures
The service SHALL include per-section `BackendIssue` entries in the snapshot when individual API calls fail, allowing successfully-fetched sections to still be returned.

#### Scenario: Single section fails
- **WHEN** the networks API call returns an error but all other calls succeed
- **THEN** `snapshot.networks` is empty, `snapshot.issues` contains one error for networks, and all other sections are populated

#### Scenario: Stats for one container fails
- **WHEN** the stats request for one container returns an error
- **THEN** that container is omitted from `snapshot.stats` and a warning issue is added; other containers' stats are returned

### Requirement: Derive active context name from socket path
The service SHALL populate `DockerResourceSnapshot.context` by extracting the Colima profile name from the socket path (e.g., `~/.colima/default/docker.sock` → `"colima"`, `~/.colima/dev/docker.sock` → `"colima-dev"`).

#### Scenario: Default profile socket path
- **WHEN** the socket path contains `/colima/default/`
- **THEN** `snapshot.context` is `"colima"`

#### Scenario: Named profile socket path
- **WHEN** the socket path contains `/colima/<profile>/`
- **THEN** `snapshot.context` is `"colima-<profile>"`
