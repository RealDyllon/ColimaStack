---
title: Architecture
description: How ColimaStack connects the macOS app, Colima CLI, Docker CLI, kubectl, and local Colima files.
---

ColimaStack is a native macOS GUI backed by local command-line tools and file-backed Colima configuration.

## Control plane

The app calls the Colima CLI for profile lifecycle and configuration-oriented operations:

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
- `docker stats --no-stream --format json`
- `docker system df --format json`

## Kubernetes inventory

Kubernetes resources are read through `kubectl`:

- `kubectl get nodes -o json`
- `kubectl get namespaces -o json`
- `kubectl get pods -A -o json`
- `kubectl get deployments -A -o json`
- `kubectl get services -A -o json`
- `kubectl top nodes`
- `kubectl top pods -A`

## File-backed documents

ColimaStack also reads selected files from Colima state:

- profile config: `$COLIMA_HOME/<profile>/colima.yaml`
- template: `$COLIMA_HOME/_templates/default.yaml`
- SSH config: `$COLIMA_HOME/ssh_config`
- daemon log: `$COLIMA_HOME/<profile>/daemon/daemon.log`

See [Command API](/reference/command-api/) for the current backend contract.
