---
title: ColimaStack vs. Docker Desktop
description: Compare a Colima-based local runtime workflow with Docker Desktop.
---

Docker Desktop is the default Docker experience for many macOS users. ColimaStack is for users who want to operate a Colima-based local runtime with a native macOS control surface.

## ColimaStack strengths

- Colima profile visibility
- native macOS app focused on local runtime operations
- explicit Docker context diagnostics
- Kubernetes visibility for Colima clusters
- transparent command output and recovery paths
- lower product scope than Docker Desktop

## Docker Desktop strengths

- first-party Docker distribution
- bundled Docker engine and CLI flow
- broad ecosystem recognition
- Docker account, extensions, and enterprise features
- built-in UI for Docker-managed runtime state

## Migration note

ColimaStack does not migrate Docker Desktop data. Move workflows deliberately by switching Docker contexts, rebuilding images as needed, and preserving important volumes before cleanup.
