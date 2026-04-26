---
title: Search
description: Search across profiles, Docker resources, Kubernetes resources, and activity.
---

ColimaStack builds a local search index from the current backend snapshot.

## Searchable areas

Search can cover:

- profiles
- containers
- images
- volumes
- networks
- Kubernetes workloads
- Kubernetes services
- activity entries

## Scope

Search results are scoped by the selected workspace section where possible. This makes broad runtime inventories easier to scan.

## Refresh behavior

The search index is rebuilt after profile refreshes and backend snapshots.
