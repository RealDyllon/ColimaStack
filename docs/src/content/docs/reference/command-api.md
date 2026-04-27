---
title: Command API
description: Exact command shapes ColimaStack invokes for Colima, Docker, Kubernetes, and diagnostics.
---

This page describes command shapes used by the current app source. It is not a stable public API; it is a source-aligned reference for troubleshooting and audits.

ColimaStack resolves executable paths through tool lookup, injects the locator `PATH`, and redacts sensitive arguments/output before displaying command history.

## Tool lookup and environment

Required binaries are searched in the process `PATH` plus:

```txt
/opt/homebrew/bin
/usr/local/bin
/opt/local/bin
/usr/bin
/bin
/usr/sbin
/sbin
```

For Docker and Kubernetes commands, the app forwards `COLIMA_HOME`, `KUBECONFIG`, `DOCKER_HOST`, `DOCKER_CONTEXT`, and proxy environment variables when present. Missing binaries become Diagnostics or backend issues.

## Colima commands

All profile-scoped Colima commands set `COLIMA_PROFILE=<profile>`.

| Purpose | Command shape | Mutates state |
| --- | --- | --- |
| Profile list | `colima list --json` | No |
| Profile status | `COLIMA_PROFILE=<profile> colima status --json` | No |
| Start/create/apply profile | `COLIMA_PROFILE=<profile> colima start [flags]` | Yes |
| Stop profile | `COLIMA_PROFILE=<profile> colima stop` | Yes |
| Restart profile | `COLIMA_PROFILE=<profile> colima restart` | Yes |
| Delete profile | `COLIMA_PROFILE=<profile> colima delete --force` | Yes |
| Enable Kubernetes | `COLIMA_PROFILE=<profile> colima kubernetes start` | Yes |
| Disable Kubernetes | `COLIMA_PROFILE=<profile> colima kubernetes stop` | Yes |
| Update profile | `COLIMA_PROFILE=<profile> colima update` | Yes |
| Edit profile config | `COLIMA_PROFILE=<profile> colima start --edit [--editor <editor>]` | Yes |
| Template editor | `COLIMA_PROFILE=<profile> colima template [--editor <editor>]` | Yes |
| SSH config | `COLIMA_PROFILE=<profile> colima ssh-config [--layer=true|false]` | No |
| SSH access | `COLIMA_PROFILE=<profile> colima ssh [--layer=true|false] [-- <command...>]` | Depends on command |

`colima start` flags are generated from the profile editor when set:

```txt
--runtime <runtime>
--vm-type <vm-type>
--arch <architecture>
--cpus <count>
--memory <GiB>
--disk <GiB>
--mount-type <mount-type>
--mount <host[:vm][:w]>
--dns <server>
--env <KEY=VALUE>
--kubernetes=true|false
--kubernetes-version <version>
--network-address=true|false
--network-preferred-route=true|false
--port-forwarder <value>
--network-mode <mode>
--network-interface <interface>
--vz-rosetta
--nested-virtualization
--k3s-arg <arg>
--k3s-listen-port <port>
```

The UI blocks profile rename on edit and requires profile-name confirmation before delete.

## Diagnostics commands

| Purpose | Command shape | Notes |
| --- | --- | --- |
| Colima version | `colima version` | Tool check |
| Docker client version | `docker version --format "{{.Client.Version}}"` | Tool check |
| kubectl client version | `kubectl version --client=true -o json` | Tool check |
| Lima version | `limactl --version` | Tool check |
| Docker context | `docker context show` | Runtime check |
| Docker server version | `docker --context <expected-context> version --format "{{.Server.Version}}"` | Used when selected profile is running and Docker runtime is expected |
| Kubernetes context | `kubectl config current-context` | Diagnostic message when `kubectl` is available |

For the default profile, the expected Docker context is `colima`. For named profiles, it is `colima-<profile>`.

## Docker inventory commands

Docker inventory is read-only. If a selected context is known, every command is prefixed with `docker --context <context>`.

| View or metric | Command shape |
| --- | --- |
| Active context | `docker context show` |
| Containers | `docker ps --all --no-trunc --format "{{json .}}"` |
| Images | `docker images --digests --no-trunc --format "{{json .}}"` |
| Volumes | `docker volume ls --format "{{json .}}"` |
| Networks | `docker network ls --no-trunc --format "{{json .}}"` |
| Container stats | `docker stats --no-stream --format "{{json .}}"` |
| Disk usage | `docker system df --format "{{json .}}"` |

Output is parsed as JSON lines. Malformed lines or records missing required fields are dropped with backend warnings. A `dead` container creates a warning issue.

Command details:

- External binary: `docker`.
- Timeout: 15 seconds.
- Mutating: no.
- Context behavior: `--context <context>` is added when the selected profile exposes one.
- Socket behavior: socket paths are displayed and indexed, but Docker inventory commands use context flags rather than passing socket paths.

Feature pages: [Containers](/docker/containers/), [Images](/docker/images/), [Volumes](/docker/volumes/), [Networks](/docker/networks/), [Monitor](/runtime/monitor/).

## Kubernetes inventory commands

Kubernetes inventory is read-only. If a selected Kubernetes context is known, every command is prefixed with `kubectl --context <context>`.

| View or metric | Command shape |
| --- | --- |
| Active context | `kubectl config current-context` |
| Nodes | `kubectl get nodes -o json` |
| Namespaces | `kubectl get namespaces -o json` |
| Pods | `kubectl get pods --all-namespaces -o json` |
| Services | `kubectl get services --all-namespaces -o json` |
| Deployments | `kubectl get deployments --all-namespaces -o json` |
| Node metrics | `kubectl top nodes --no-headers` |
| Pod metrics | `kubectl top pods --all-namespaces --no-headers` |

Command details:

- External binary: `kubectl`.
- Timeout: 20 seconds.
- Mutating: no.
- Namespace behavior: pods, services, deployments, and pod metrics use `--all-namespaces`; nodes and namespaces are cluster-scoped.
- Metrics behavior: failed `kubectl top` commands create informational issues, not fatal errors.

Feature pages: [Kubernetes](/kubernetes/overview/), [Workloads](/kubernetes/workloads/), [Services](/kubernetes/services/).

## Local files

| Document | Path |
| --- | --- |
| Colima home | `$COLIMA_HOME` or `~/.colima` |
| Profile config | `$COLIMA_HOME/<profile>/colima.yaml` |
| Default template | `$COLIMA_HOME/_templates/default.yaml` |
| SSH config | `$COLIMA_HOME/ssh_config` |
| Daemon log | `$COLIMA_HOME/<profile>/daemon/daemon.log` |

See [Security & Privacy](/security-privacy/) for redaction, indexing, copy behavior, and stored output limits.
