---
title: ColimaStack vs. Colima CLI
description: Compare native GUI workflows with direct Colima command-line usage.
---

ColimaStack complements the Colima CLI. It does not remove the need to understand Colima, especially for advanced runtime configuration and debugging.

## Use ColimaStack for

- visual profile selection
- lifecycle actions
- setup diagnostics
- Docker resource inventory
- Kubernetes resource inventory
- command history
- logs and failure recovery
- repeatable profile editing

## Use the CLI for

- scripts and automation
- unsupported advanced flags
- experimental Colima features
- low-level troubleshooting
- workflows not yet surfaced in the app

## Shared contract

ColimaStack intentionally follows Colima's command contract. See [Command API](/reference/command-api/) for the current mapping.
