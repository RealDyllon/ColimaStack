---
title: Services
description: Inspect Kubernetes services across namespaces in the selected Colima Kubernetes context.
---

`Services` lists Kubernetes services returned by `kubectl` for the selected Kubernetes-enabled Colima profile.

## What this view shows

- Service name.
- Namespace.
- Service type or cluster IP.
- Ports.
- External IPs when returned by Kubernetes.

Services are queried across all namespaces.

## How to get data to appear

1. Enable Kubernetes for the selected profile.
2. Make sure the profile is running.
3. Create services in the cluster.
4. Click `Refresh`.

Terminal check:

```sh
kubectl get services --all-namespaces
```

## Available actions

The view is read-only in the current source. It does not expose port-forward, edit, delete, or describe actions.

## Empty states

- `Services unavailable`: Colima diagnostics need to complete.
- `No profile selected`: select a profile first.
- `Kubernetes is disabled`: enable Kubernetes on the selected profile.
- `No services reported by kubectl`: no services were returned or the command failed.
- `No services match the current search`: local search filtered the list.

## Source command

```sh
kubectl --context <context> get services --all-namespaces -o json
```

See [Command API](/reference/command-api/), [Compatibility](/compatibility/), and [Diagnostics](/features/diagnostics/).
