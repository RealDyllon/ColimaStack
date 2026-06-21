---
title: Kubernetes
description: Inspect Kubernetes cluster state for the selected Colima profile.
---

Kubernetes views appear in the app sidebar as `Cluster`, `Workloads`, and `Services`. They are available only when Kubernetes is enabled for the selected Colima profile and `kubectl` can reach the selected context.

![ColimaStack Kubernetes Cluster screenshot](/screenshots/kubernetes-cluster.png)

## What Cluster shows

- Kubernetes context.
- Kubernetes version reported by the profile.
- Node count.
- Profile state.
- Cluster identity values.
- Nodes with name, roles, kubelet version, and Ready condition.

## How to get data to appear

1. Select a Colima profile.
2. Enable Kubernetes in the profile editor or use `Enable Kubernetes` from `Cluster` or the menu bar.
3. Start or restart the profile if required.
4. Confirm `kubectl` can reach the context.
5. Click `Refresh`.

Minimal check:

```sh
kubectl config current-context
kubectl get nodes
```

## Available actions

- `Enable Kubernetes` when Kubernetes is disabled.
- `Disable Kubernetes` when enabled.
- `Restart Profile`.
- Navigate to `Workloads` and `Services`.

Kubernetes resource views are read-only; the app does not create, update, delete, or apply Kubernetes objects.

## Empty states

- `Cluster state unavailable`: Colima diagnostics are unavailable.
- `Select a profile`: Kubernetes state is scoped to one profile.
- `Kubernetes is disabled`: the selected profile does not have Kubernetes enabled.
- `No nodes reported by kubectl`: `kubectl get nodes -o json` returned no nodes or the command failed.
- `No nodes match the current search`: local search filtered the rows.

## Source commands

ColimaStack invokes:

```sh
kubectl --context <context> config current-context
kubectl --context <context> get nodes -o json
kubectl --context <context> get namespaces -o json
kubectl --context <context> top nodes --no-headers
```

See [Command API](/reference/command-api/), [Compatibility](/compatibility/), and [Diagnostics](/features/diagnostics/).
