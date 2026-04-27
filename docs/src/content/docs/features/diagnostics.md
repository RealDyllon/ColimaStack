---
title: Diagnostics
description: Check local tool availability, Colima runtime state, Docker context health, and Kubernetes context.
---

`Diagnostics` answers whether ColimaStack can control and inspect the selected local runtime.

## What checks run

Tool checks:

- `colima version`
- `docker version --format "{{.Client.Version}}"`
- `kubectl version --client=true -o json`
- `limactl --version`

Runtime checks:

- selected profile `colima status --json`
- Docker active context with `docker context show`
- Docker server version against the expected Colima context when the selected profile is running
- Kubernetes current context with `kubectl config current-context` when `kubectl` is available

## What data is collected

The screen shows:

- tool availability, path, and version or error
- Colima profile name and state
- Colima runtime error text when available
- Docker available yes/no
- Docker context and version
- Docker error text
- diagnostic messages such as Kubernetes context availability

## Available actions

- `Run Checks`: refreshes diagnostics and runtime data.
- Menu bar `Copy Diagnostics Summary`: copies a short summary with profile, Colima state, Docker availability/context, resource counts, and issue count.

Copy uses the visible summary value. Redaction happens before data is displayed, not as an extra pasteboard step.

## Empty states

- `No tool checks captured yet`: diagnostics have not run.
- `No diagnostic messages`: no additional context messages were collected.
- Missing Colima clears profile/runtime data and shows a `Colima is not installed` issue with a `brew install colima` recovery suggestion.

## Redaction

Diagnostics text is redacted for common secrets, tokens, passwords, credentials, and authorization patterns. See [Security & Privacy](/security-privacy/) for the exact scope and limitations.

## Common fixes

- Install missing tools from [Install](/install/).
- Start the selected profile in [Profiles](/profiles/overview/).
- Check exact command shapes in [Command API](/reference/command-api/).
- Use [Compatibility](/compatibility/) to confirm supported macOS and optional feature requirements.
