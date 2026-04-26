---
title: What is ColimaStack?
description: ColimaStack is a native macOS control center for Colima profiles, Docker resources, and Kubernetes development clusters.
---

ColimaStack is a native macOS app for developers who use [Colima](https://github.com/abiosoft/colima) as their local container runtime. It gives Colima a focused graphical workspace for profile lifecycle, runtime inventory, Kubernetes visibility, setup diagnostics, logs, and command feedback.

Colima is already a strong open-source foundation for local containers. ColimaStack is the product layer on top: a fast way to see what is running, switch profiles, start and stop runtimes, inspect Docker resources, and understand why a local environment is unhealthy.

## Why ColimaStack?

- Native Colima workflow: manage profiles, runtime settings, and Kubernetes toggles without memorizing every CLI flag.
- Docker visibility: browse containers, images, volumes, networks, stats, and disk usage for the active Colima context.
- Kubernetes visibility: inspect nodes, namespaces, pods, deployments, services, and metrics when Kubernetes is enabled.
- Setup diagnostics: identify missing or misconfigured `colima`, `docker`, `kubectl`, and `limactl` tools.
- Command transparency: see operations, terminal output, logs, and recovery details when commands fail.

## Getting started

Start with the [Quick start](/quick-start/) guide, then review [Install](/install/) for dependency setup.

If you are evaluating alternatives, compare ColimaStack with [OrbStack](/compare/orbstack/), [Docker Desktop](/compare/docker-desktop/), and the [Colima CLI](/compare/colima-cli/).

## Current scope

This documentation reflects the launch surface currently represented in the app and release notes. Some pages document intended launch behavior that still requires final manual smoke testing with a live Colima installation.
