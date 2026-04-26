---
title: Command API
description: The Colima, Docker, and Kubernetes command contract used by ColimaStack.
---

This page summarizes the app-owned command contract. The source reference is the repository document at `docs/colima-command-api-reference.md`.

## Colima control commands

| Capability | Command surface |
| --- | --- |
| Tool diagnostics | `colima version`, `colima status --json` |
| Profile list | `colima list --json` |
| Profile status | `colima status --json` |
| Start profile | `colima start` plus profile flags |
| Stop profile | `colima stop` |
| Restart profile | `colima restart` |
| Delete profile | `colima delete --force` after app confirmation |
| Kubernetes toggle | `colima kubernetes start` and `colima kubernetes stop` |
| Runtime update | `colima update` |
| Template editing | `colima template` |
| Profile config editing | `colima start --edit` |
| SSH config | `colima ssh-config` |
| SSH access | `colima ssh` |

## Docker read APIs

| Screen | Command |
| --- | --- |
| Containers | `docker ps -a --format json` |
| Images | `docker images --format json` |
| Volumes | `docker volume ls --format json` |
| Networks | `docker network ls --format json` |
| Metrics | `docker stats --no-stream --format json` |
| Disk usage | `docker system df --format json` |

## Kubernetes read APIs

| Screen | Command |
| --- | --- |
| Cluster nodes | `kubectl get nodes -o json` |
| Namespaces | `kubectl get namespaces -o json` |
| Pods | `kubectl get pods -A -o json` |
| Deployments | `kubectl get deployments -A -o json` |
| Services | `kubectl get services -A -o json` |
| Metrics | `kubectl top nodes`, `kubectl top pods -A` |

## Path conventions

| Document | Path |
| --- | --- |
| Profile config | `$COLIMA_HOME/<profile>/colima.yaml` |
| Default template | `$COLIMA_HOME/_templates/default.yaml` |
| SSH config | `$COLIMA_HOME/ssh_config` |
| Daemon log | `$COLIMA_HOME/<profile>/daemon/daemon.log` |
