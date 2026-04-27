---
title: Activity and Logs
description: Review command progress, command history, command output, and selected-profile daemon logs.
---

`Activity` shows app-initiated lifecycle operations and the selected profile's Colima daemon log.

![ColimaStack Activity screenshot](/screenshots/activity.png)

## What this view shows

- `Command running` banner while a mutating operation is active.
- `Total commands`, `Failures`, `Running`, and `Logs` tiles.
- Command history, newest first.
- Command status: running, succeeded, or failed.
- Captured command output with `Expand output` / `Collapse output`.
- `Terminal output` from the selected profile log.

## Log sources

Command history comes from app-initiated operations such as `Start`, `Stop`, `Restart`, `Delete`, `Update Profile`, `Create`, `Apply`, and Kubernetes toggle actions.

Profile logs are read from:

```txt
$COLIMA_HOME/<profile>/daemon/daemon.log
```

or `~/.colima/<profile>/daemon/daemon.log` when `COLIMA_HOME` is not set.

Docker and Kubernetes read-only inventory commands are collected as backend command runs for issues/search, but the visible Activity command history is the app-level command log.

## Caps and truncation

- Command history is capped at 200 entries.
- Displayed profile logs are capped to the last 200,000 characters.
- Process stdout and stderr are capped at 1,048,576 bytes per stream and marked when truncated.

## Refresh behavior

Click `Refresh` or leave `Auto Refresh` enabled. Auto-refresh runs every `Normal` 10 seconds by default and skips while a command is active or the profile editor is open.

## Empty states

- `No command history yet`: no app lifecycle operations have run in this session.
- `No matching activity`: local search filtered the command history.
- Missing profile log: the terminal output area shows the missing daemon log path.

## Common fixes

- Use [Profiles](/profiles/overview/) to run a lifecycle action and populate command history.
- Use [Diagnostics](/features/diagnostics/) when commands fail.
- See [Security & Privacy](/security-privacy/) for redaction and storage limits.
