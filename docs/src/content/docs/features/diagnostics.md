---
title: Diagnostics
description: Understand dependency checks and runtime health in ColimaStack.
---

Diagnostics answer a simple question: can ColimaStack control and inspect the selected local runtime?

## Tool checks

The app checks:

- `colima`
- `docker`
- `kubectl`
- `limactl`

Each check reports whether the tool is available, missing, or returned an error.

## Runtime checks

Colima status is read with `colima status --json` where possible. A stopped profile is treated as a normal state, not a fatal error.

Docker availability is checked against the expected Colima context so an unrelated active Docker context does not hide a local setup problem.

## Kubernetes context

If `kubectl` is available, diagnostics include the current Kubernetes context or the error returned by `kubectl config current-context`.
