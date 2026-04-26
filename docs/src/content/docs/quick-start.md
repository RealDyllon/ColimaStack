---
title: Quick Start
description: Install prerequisites, launch ColimaStack, and start managing a Colima profile.
---

Use this guide to get from a clean macOS development machine to a visible Colima runtime in ColimaStack.

## Prerequisites

Install the command-line tools ColimaStack expects:

```sh
brew install colima docker kubectl
```

Colima also uses Lima under the hood. If your Colima installation did not install `limactl`, install Lima explicitly:

```sh
brew install lima
```

## Launch ColimaStack

Open the ColimaStack macOS app. On first launch, the app runs diagnostics for:

- `colima`
- `docker`
- `kubectl`
- `limactl`
- Colima runtime status
- Docker context availability
- Kubernetes context availability

If a dependency is missing, open [Diagnostics](/features/diagnostics/) and follow the recovery suggestion.

## Create or select a profile

If you already use Colima, your profiles should appear automatically. Select a profile in the sidebar, then use the workspace actions to refresh, start, stop, restart, update, or edit it.

To create a profile, open Profiles and choose Create Profile. Configure CPU, memory, disk, runtime, VM type, mounts, DNS, networking, and Kubernetes settings before starting it.

## Verify Docker

After a profile is running, open Containers. You can also run a smoke-test container in Terminal:

```sh
docker context use colima
docker run --rm hello-world
```

For named profiles, the Docker context is usually `colima-<profile>`.

## Verify Kubernetes

Enable Kubernetes for the selected profile, then open the Kubernetes views. From Terminal:

```sh
kubectl config current-context
kubectl get nodes
```

If metrics are unavailable, install or enable the Kubernetes metrics server for the cluster.
