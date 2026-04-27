---
title: Quick Start
description: Install prerequisites, launch ColimaStack, and start managing a Colima profile.
---

Use this guide to get from a clean macOS development machine to a visible Colima runtime in ColimaStack.

## Prerequisites

Install Colima:

```sh
brew install colima
```

Install the Docker CLI only if you want Docker resource views such as containers, images, volumes, networks, stats, and disk usage:

```sh
brew install docker
```

Homebrew installs Lima as a Colima dependency. Install `kubectl` only if you plan to enable Kubernetes for a Colima profile. If ColimaStack diagnostics report that `limactl` is missing, install Lima explicitly with `brew install lima`.

## Launch ColimaStack

Open the ColimaStack macOS app. On first launch, the app runs diagnostics for:

- `colima`
- `docker`
- `kubectl`
- `limactl`
- Colima runtime status
- Docker context availability
- Kubernetes context availability

Only `colima` is required for core profile management. Missing optional tools limit the related views: Docker CLI for Docker inventory, `kubectl` for Kubernetes inventory, and `limactl` for deeper runtime diagnostics. If a dependency is missing, open [Diagnostics](/features/diagnostics/) and follow the recovery suggestion for the workflow you want to use.

## Create or select a profile

If you already use Colima, your profiles should appear automatically. Select a profile in the sidebar, then use the workspace actions to refresh, start, stop, restart, update, or edit it.

To create a profile, open Profiles and choose Create Profile. Configure CPU, memory, disk, runtime, VM type, mounts, DNS, networking, and Kubernetes settings before starting it.

## Inspect runtime state

After a profile is running, open Containers, Images, Volumes, or Networks to inspect the Docker runtime through ColimaStack.

If Kubernetes is enabled for the selected profile, open the Kubernetes views to inspect nodes, pods, deployments, and services. If metrics are unavailable, ColimaStack shows the missing data in the workspace so you can decide whether to install or enable the Kubernetes metrics server for the cluster.
