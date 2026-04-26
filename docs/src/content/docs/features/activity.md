---
title: Activity and Logs
description: Track command progress, command history, terminal output, and Colima daemon logs.
---

Activity keeps the GUI honest by showing what ColimaStack asked the local toolchain to do.

## Command progress

Long-running operations such as start, stop, restart, update, and delete appear as active operations while they are running.

## Command history

Recent commands are retained in the workspace so failures can be inspected after the UI returns to an idle state.

## Terminal output

When a command fails, ColimaStack includes stdout and stderr in the failure details where available.

## Profile logs

Daemon logs are read from:

```txt
$COLIMA_HOME/<profile>/daemon/daemon.log
```

The UI caps very large logs so the app remains responsive.
