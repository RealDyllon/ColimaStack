---
title: Kubernetes
description: Manage and inspect Kubernetes support for Colima profiles.
---

ColimaStack can enable or disable Kubernetes for a profile through Colima:

```sh
colima kubernetes start
colima kubernetes stop
```

The Kubernetes views use `kubectl` for cluster inventory. Install `kubectl` only if you want to use these views.

## Cluster view

The cluster view focuses on nodes, namespaces, and cluster health.

## Workloads view

The workloads view focuses on pods and deployments across namespaces.

## Services view

The services view focuses on Kubernetes services across namespaces.

## Metrics

Node and pod metrics depend on the cluster exposing metrics to `kubectl top`.
