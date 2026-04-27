---
title: Frequently Asked Questions
description: Common questions about ColimaStack, Colima, Docker contexts, Kubernetes, and releases.
---

## Is ColimaStack a replacement for Colima?

No. ColimaStack depends on Colima. It invokes `colima` for profile lifecycle operations and reads Colima profile status/files.

## Does ColimaStack include Docker?

No. Docker inventory requires the Docker CLI and a running Docker-backed Colima profile.

## Can I use multiple Colima profiles?

Yes. Profiles returned by `colima list --json` appear in the sidebar and `Profiles` view. Named Docker contexts usually follow `colima-<profile>`.

## Does Kubernetes work?

Yes, when Kubernetes is enabled on the selected Colima profile and `kubectl` can reach the selected context. Metrics require `kubectl top` support.

## Is there a public notarized app bundle?

The repository does not currently document a verified public Developer ID app bundle. Use [Install](/install/) to build from source.

## Does ColimaStack send telemetry?

The reviewed source does not show telemetry code. It does run local CLIs, read local Colima files, and keep local in-memory state for UI/search. See [Security & Privacy](/security-privacy/).

## Can I still use the terminal?

Yes. ColimaStack uses the same local command-line tools. Refresh the app after changing resources from Terminal.
