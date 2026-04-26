---
title: Documentation Plan
description: Plan for making ColimaStack documentation comparable in usefulness to the OrbStack docs.
---

OrbStack's documentation sets a useful bar: clear product framing, quick start, install and migration paths, feature explanations, Docker docs, Kubernetes docs, Linux machine docs, comparison pages, and support/legal material.

ColimaStack should match that breadth where the product supports it, while staying honest about its architecture as a Colima-focused native app.

## Keep from the OrbStack model

- A short homepage explaining what the product is.
- Quick start that reaches a successful container run quickly.
- Install page with side-by-side migration notes.
- Feature pages for diagnostics, logs, search, and menu bar workflows.
- Docker pages split by containers, images, volumes, and networking.
- Kubernetes pages split by cluster, workloads, and services.
- Comparison pages for the tools users will evaluate.
- Reference pages for commands and release readiness.

## Adapt for ColimaStack

- Replace OrbStack Linux machines with Colima profiles.
- Replace automatic domains and HTTPS with Colima networking, Docker contexts, and port-forwarding behavior.
- Emphasize dependency diagnostics because ColimaStack relies on local CLIs.
- Emphasize command transparency because the GUI delegates to Colima, Docker, and kubectl.
- Document profile configuration deeply because that is ColimaStack's highest-value control surface.

## Content still needed

- Actual screenshots from the app.
- Exact install and update channel for public builds.
- A signed/notarized app installation guide.
- Full troubleshooting pages sourced from real support cases.
- Security and privacy notes for local command execution.
- Compatibility matrix for macOS, Colima, Docker CLI, kubectl, Lima, and architectures.
