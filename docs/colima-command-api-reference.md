# Colima Command API Reference

Verified against the upstream Colima commands reference on April 26, 2026: [colima.run/docs/commands](https://colima.run/docs/commands/).

This document describes the command-facing API that ColimaStack expects from the `colima` CLI and adjacent Docker/Kubernetes tools. The first table is the app-owned implementation contract; the full upstream Colima command index is included below so command drift is visible in this codebase.

## Product framing

Based on the current launch surface in [design/mockups/screen_inventory.md](/Users/dyllon/Developer/colima-stack/design/mockups/screen_inventory.md), the launch-critical objective is local Colima lifecycle management with:

- setup and dependency diagnostics
- profile listing and selection
- Docker containers, images, volumes, networks, stats, and disk usage for the active Colima context
- start, stop, restart, delete, and update flows
- Kubernetes enablement plus nodes, namespaces, pods, deployments, services, and metrics visibility
- profile configuration editing and SSH access
- command/log feedback for failure recovery

The product objective is a public macOS developer launch: a polished Colima GUI credible for Hacker News, Product Hunt, newsletter/podcast coverage, and direct comparison with OrbStack and Docker Desktop for local runtime workflows.

## Command surface in code

`LiveColimaCLI` currently models these commands:

| App capability | Colima command(s) | Backend entry point | Notes |
| --- | --- | --- | --- |
| Tool diagnostics | `colima version`, `colima status --json` | `diagnostics()` | Also probes `docker`, `kubectl`, `limactl`. |
| Profile list | `colima list --json` | `listProfiles()` | JSON is the primary contract; parser also tolerates plain text fallback. |
| Profile status | `colima status --json` | `status(profile:)` | Non-zero exit with “not running” is treated as stopped, not fatal. |
| Daemon logs | filesystem at `$COLIMA_HOME/<profile>/daemon/daemon.log` | `logs(profile:)` | Does not shell out to `colima logs`. |
| Start profile | `colima start` plus flags | `start(_:)` | Built from `ProfileConfiguration`. |
| Stop profile | `colima stop` | `stop(profile:)` | Uses `COLIMA_PROFILE`. |
| Restart profile | `colima restart` | `restart(profile:)` | Uses `COLIMA_PROFILE`. |
| Delete profile | `colima delete` | `delete(profile:)` | Current app path supports `--force` internally, not `--data`. |
| Kubernetes toggle | `colima kubernetes start|stop` | `kubernetes(profile:enabled:)` | No reset flow exposed yet. |
| Runtime update | `colima update` | `update(profile:)` | Profile-scoped via environment. |
| Read template/config | files under `$COLIMA_HOME` | `template()`, `configuration(profile:)` | Reads YAML directly from disk. |
| Edit template | `colima template [--editor ...]` | `editTemplate(_:)` | Command-based editor launch. |
| Edit profile config | `colima start --edit [--editor ...]` | `editProfileConfiguration(_:)` | Reuses `start --edit`, matching upstream docs. |
| SSH config | `colima ssh-config [--layer=...]` | `sshConfigurationDocument(profile:layer:)` | Returns CLI output or stored file content. |
| SSH command | `colima ssh [--layer=...] [-- ...]` | `ssh(_:)` | Supports interactive shell or command pass-through. |

## Docker and Kubernetes resource surface

ColimaStack uses Docker and kubectl as the stable read APIs for runtime inventory. These calls are scoped by the selected Colima profile/context where possible.

| App screen | Tool command(s) | Backend entry point |
| --- | --- | --- |
| Containers | `docker ps -a --format json` | `DockerResourceService.snapshot(profile:)` |
| Images | `docker images --format json` | `DockerResourceService.snapshot(profile:)` |
| Volumes | `docker volume ls --format json` | `DockerResourceService.snapshot(profile:)` |
| Networks | `docker network ls --format json` | `DockerResourceService.snapshot(profile:)` |
| Metrics | `docker stats --no-stream --format json`, `docker system df --format json` | `DockerResourceService.snapshot(profile:)` |
| Cluster nodes | `kubectl get nodes -o json` | `KubernetesResourceService.snapshot(profile:)` |
| Namespaces | `kubectl get namespaces -o json` | `KubernetesResourceService.snapshot(profile:)` |
| Pods | `kubectl get pods -A -o json` | `KubernetesResourceService.snapshot(profile:)` |
| Deployments | `kubectl get deployments -A -o json` | `KubernetesResourceService.snapshot(profile:)` |
| Services | `kubectl get services -A -o json` | `KubernetesResourceService.snapshot(profile:)` |
| K8s metrics | `kubectl top nodes`, `kubectl top pods -A` | `KubernetesResourceService.snapshot(profile:)` |

## `colima start` flag mapping

The app currently maps `ProfileConfiguration` into these upstream `start` flags:

| Domain field | Flags emitted |
| --- | --- |
| `runtime` | `--runtime <docker|containerd|incus>` |
| `vmType` | `--vm-type <qemu|vz|krunkit>` |
| `architecture` | `--arch <aarch64|x86_64>` |
| `resources.cpu` | `--cpus <n>` |
| `resources.memoryGiB` | `--memory <n>` |
| `resources.diskGiB` | `--disk <n>` |
| `mountType` | `--mount-type <sshfs|9p|virtiofs>` |
| `mounts` | repeated `--mount <value>` |
| `network.dnsResolvers` | repeated `--dns <ip>` |
| `kubernetes.enabled` | `--kubernetes=true|false` |
| `kubernetes.version` | `--kubernetes-version <version>` |
| `network.networkAddress` | `--network-address=true|false` |
| `portForwarder` | `--port-forwarder <ssh|grpc|none>` |
| `network.mode` when not `shared` | `--network-mode <mode>` |
| `network.interface` | `--network-interface <name>` |
| `k3sArgs` | repeated `--k3s-arg <arg>` |
| `k3sListenPort` | `--k3s-listen-port <port>` |
| `additionalArgs` | appended verbatim |

Behavioral constraints already encoded by tests:

- host architecture is omitted rather than emitted as `--arch host`
- blank DNS, blank k3s args, and blank network interface values are dropped
- default shared networking is omitted
- invalid profile configuration fails before any process launch

## Profile and path conventions

ColimaStack currently relies on these conventions:

- `COLIMA_PROFILE` selects the target profile for all non-list commands.
- `COLIMA_HOME` overrides the Colima state directory.
- default profile name is `default`.
- Docker context is derived as `colima` for the default profile and `colima-<profile>` for named profiles.
- profile config path: `$COLIMA_HOME/<profile>/colima.yaml`
- template path: `$COLIMA_HOME/_templates/default.yaml`
- daemon log path: `$COLIMA_HOME/<profile>/daemon/daemon.log`
- SSH config path: `$COLIMA_HOME/ssh_config`

## Upstream Colima command index

The official command page describes the full Colima CLI surface as of April 26, 2026:

- `colima start [profile] [flags]`
- `colima stop [profile] [flags]`
- `colima restart [profile] [flags]`
- `colima delete [profile] [flags]`
- `colima status [profile] [flags]`
- `colima list [flags]`
- `colima ssh [profile] [flags] [-- command]`
- `colima ssh-config [profile] [flags]`
- `colima kubernetes start|stop|reset [profile]`
- `colima model run|serve <model> [flags]`
- `colima nerdctl [profile] -- [command]`
- `colima nerdctl install`
- `colima template [flags]`
- `colima update [flags]`
- `colima prune [profile] [flags]`
- `colima version`
- `colima completion [shell]`

Launch scope implements lifecycle, diagnostics, profile configuration, SSH/config access, Kubernetes start/stop, and Docker/Kubernetes read visibility. `logs`, `kubernetes reset`, `model`, `nerdctl`, `prune`, and `completion` remain documented here for completeness, but are not exposed as first-class GUI actions in this release.

## Compatibility notes

There are a few intentional differences between upstream documentation and the app’s current backend contract:

- Upstream documents `colima start [profile]`; the app passes profile selection through `COLIMA_PROFILE`.
- Upstream documents `colima template` as command output; the app reads the template file directly for display and only shells out when opening it in an editor.

## Release validation checklist

- Confirm every command/flag above still matches the Colima release targeted for launch.
- Run fake-runner tests for command construction and file-backed document reads.
- Perform one manual smoke pass with a real Colima install for:
  - list
  - status
  - start
  - stop
  - delete
  - Kubernetes start/stop
  - SSH config
- Reconcile any upstream flag drift before shipping.
