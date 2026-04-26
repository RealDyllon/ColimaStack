---
title: Features
description: The main ColimaStack capabilities for local container and Kubernetes development.
---

ColimaStack is organized around the workflows developers repeat every day: check runtime health, start or stop a profile, inspect Docker resources, verify Kubernetes state, and recover from toolchain failures.

## Workspace overview

The overview screen summarizes the selected profile, runtime state, Docker context, socket, address, resources, Kubernetes status, diagnostics, recent activity, and profile logs.

## Profile management

Create, edit, start, stop, restart, update, and delete Colima profiles. Profile configuration covers runtime, VM type, CPU, memory, disk, architecture, mounts, DNS, port forwarding, Kubernetes, and advanced Colima flags.

## Docker resources

ColimaStack reads Docker resources through the Docker CLI for the active Colima context:

- containers
- images
- volumes
- networks
- runtime stats
- Docker system disk usage

## Kubernetes resources

When Kubernetes is enabled for a profile, ColimaStack reads cluster state through `kubectl`:

- nodes
- namespaces
- pods
- deployments
- services
- node and pod metrics when available

## Diagnostics and recovery

The diagnostics workflow checks for required tools, Colima runtime status, Docker availability, and Kubernetes context. Errors are surfaced as actionable messages instead of raw command failures where possible.
