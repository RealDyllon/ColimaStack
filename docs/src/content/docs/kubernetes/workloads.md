---
title: Workloads
description: Inspect pods and deployments across namespaces in the selected Colima Kubernetes context.
---

`Workloads` lists pods and deployments returned by `kubectl` for the selected Kubernetes-enabled Colima profile.

![ColimaStack Workloads screenshot](/screenshots/kubernetes-workloads.png)

## What this view shows

- Pods: name, namespace, node, and phase.
- Deployments: name, namespace, ready replicas, desired replicas, and updated replicas.
- Health coloring based on pod phase/readiness and deployment replica availability.

Pods and deployments are queried across all namespaces.

## How to get data to appear

1. Enable Kubernetes for the selected profile.
2. Make sure the profile is running.
3. Create or run workloads in the cluster.
4. Click `Refresh`.

Example terminal check:

```sh
kubectl get pods --all-namespaces
kubectl get deployments --all-namespaces
```

## Available actions

The view is read-only in the current source. It does not scale, restart, delete, describe, or stream logs for workloads.

## Empty states

- `Workloads unavailable`: Colima diagnostics need to complete.
- `No profile selected`: select a profile first.
- `Kubernetes is disabled`: enable Kubernetes on the selected profile.
- `No pods reported by kubectl`: no pods were returned or the command failed.
- `No deployments reported by kubectl`: no deployments were returned or the command failed.
- Search-specific empty states mean local filtering matched no rows.

## Metrics

Kubernetes metrics are collected with `kubectl top`, but this page primarily lists resource state. Metrics may be unavailable when the cluster does not have metrics support.

## Source commands

```sh
kubectl --context <context> get pods --all-namespaces -o json
kubectl --context <context> get deployments --all-namespaces -o json
kubectl --context <context> top pods --all-namespaces --no-headers
```

See [Command API](/reference/command-api/), [Compatibility](/compatibility/), and [Diagnostics](/features/diagnostics/).
