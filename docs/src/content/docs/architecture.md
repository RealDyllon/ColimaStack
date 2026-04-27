---
title: Architecture
description: How ColimaStack connects the macOS app, Colima CLI, Docker CLI, kubectl, and local Colima files.
---

ColimaStack is a SwiftUI macOS app backed by local command-line tools and selected Colima files.

## Control plane

Profile discovery and lifecycle operations use `colima`. Profile-scoped commands set `COLIMA_PROFILE=<profile>`.

Key command shapes:

- `colima list --json`
- `COLIMA_PROFILE=<profile> colima status --json`
- `COLIMA_PROFILE=<profile> colima start [flags]`
- `COLIMA_PROFILE=<profile> colima stop`
- `COLIMA_PROFILE=<profile> colima restart`
- `COLIMA_PROFILE=<profile> colima delete --force`
- `COLIMA_PROFILE=<profile> colima update`
- `COLIMA_PROFILE=<profile> colima kubernetes start|stop`

See [Command API](/reference/command-api/) for the full command list and flags.

## Docker inventory

Docker resources are read through the Docker CLI. When the selected profile exposes a context, commands are prefixed with `docker --context <context>`.

The app reads containers, images, volumes, networks, stats, and disk usage. These inventory commands are read-only.

## Kubernetes inventory

Kubernetes resources are read through `kubectl`. When the selected profile exposes a Kubernetes context, commands are prefixed with `kubectl --context <context>`.

The app reads nodes, namespaces, pods, deployments, services, and `kubectl top` metrics. Kubernetes views are read-only in the current source.

## Refresh and aggregation

On refresh, the app runs diagnostics, reloads profiles, refreshes the selected profile, reads the selected profile log, and loads backend Docker/Kubernetes snapshots only when the selected profile is running. Docker snapshots are skipped for non-Docker runtimes. Kubernetes snapshots are skipped when Kubernetes is disabled.

Auto-refresh can run every 2, 5, or 10 seconds and skips while a command is active or the profile editor is open.

## File-backed documents

ColimaStack reads selected files from `$COLIMA_HOME` or `~/.colima`:

- profile config: `$COLIMA_HOME/<profile>/colima.yaml`
- template: `$COLIMA_HOME/_templates/default.yaml`
- SSH config: `$COLIMA_HOME/ssh_config`
- Lima override: `$COLIMA_HOME/_lima/_config/override.yaml`
- daemon log: `$COLIMA_HOME/<profile>/daemon/daemon.log`

See [Security & Privacy](/security-privacy/) for redaction, local storage, and copy behavior.
