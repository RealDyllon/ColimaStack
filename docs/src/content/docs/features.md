---
title: Features
description: Source-verified ColimaStack capabilities grouped by task.
---

ColimaStack is organized around the selected Colima profile.

## Workspace

- `Overview`: selected profile state, runtime context, diagnostics snapshot, recent activity, and profile logs.
- `Profiles`: profile roster and lifecycle controls.
- `Activity`: app command history and selected profile daemon logs.

## Runtime

- `Containers`: all containers from the selected Docker context.
- `Images`: images, tags, digests, and sizes.
- `Volumes`: profile mounts and Docker-managed volumes.
- `Networks`: Colima endpoint details and Docker networks.
- `Monitor`: Docker-based CPU, memory, disk, network, block I/O, capacity, and health signals.

## Kubernetes

- `Cluster`: context, version, nodes, and cluster identity.
- `Workloads`: pods and deployments across namespaces.
- `Services`: services across namespaces.

Kubernetes data requires Kubernetes to be enabled on the selected profile and `kubectl` to be available.

## Support

- `Diagnostics`: local tool checks and runtime health.
- `Search`: local filtering and indexed resource metadata.
- `Menu Bar`: profile, Docker, Kubernetes, diagnostics, copy, and navigation actions.

Read [Command API](/reference/command-api/) for exact command shapes.
