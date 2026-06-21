---
title: Compatibility
description: Current verified and not-yet-verified platform support for ColimaStack.
---

This matrix reflects the repository state reviewed on 2026-04-27. It separates verified source facts from dependencies that are handled by Colima, Docker CLI, kubectl, or Lima.

| Area | Status |
| --- | --- |
| macOS | Xcode project deployment target is macOS 14.0. |
| CPU architecture | The app project does not pin a single architecture. Profile configuration exposes `Architecture` choices through Colima, including host architecture and non-host choices. Apple Silicon and Intel support should be verified with local builds before a public release claim. |
| Colima | Required. The app invokes `colima` for profile discovery, status, lifecycle actions, Kubernetes toggles, update, SSH/config helpers, and diagnostics. |
| Docker CLI | Required for Docker inventory and monitor data. Docker resources are collected through `docker` commands against the selected Colima Docker context. |
| kubectl | Optional. Required for Kubernetes `Cluster`, `Workloads`, `Services`, and Kubernetes metrics. |
| Lima / limactl | Checked by Diagnostics. Homebrew usually installs Lima with Colima; install it explicitly if missing. |
| Runtime | Docker runtime is documented. Backend Docker inventory is skipped when the selected profile is not a Docker runtime. |
| Kubernetes | Supported only when enabled on the selected Colima profile and when the selected Kubernetes context is reachable. |
| VM type | Profile editor exposes Colima VM type choices. VM behavior is delegated to Colima/Lima. |
| Mount driver | Profile editor exposes Colima mount driver choices and configured mounts. Mount behavior is delegated to Colima/Lima. |
| Rosetta | Profile editor exposes `Rosetta` only for compatible `vz` profile settings. Behavior is delegated to Colima. |
| Nested virtualization | Profile editor exposes `Nested Virtualization` only for `vz`. Behavior is delegated to Colima. |
| Krunkit | Not surfaced in the current app UI or command layer. |
| Public signed release | Not verified in the repository. Build from source is the documented path. |

## Known unsupported or not yet verified

- Non-Docker Colima runtimes do not populate Docker inventory.
- Kubernetes views stay empty or show issues when Kubernetes is disabled, `kubectl` is missing, or the context is unavailable.
- Public Developer ID signing and notarization are maintainer release tasks, not current user prerequisites.
- Clean-machine public install behavior is not documented as verified beyond source builds.

Related setup pages: [Install](/install/), [Quick Start](/quick-start/), [Profiles](/profiles/overview/), [Kubernetes](/kubernetes/overview/), and [Diagnostics](/features/diagnostics/).
