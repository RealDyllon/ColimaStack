---
title: Files and Logs
description: Understand Colima files that ColimaStack reads for profile details.
---

ColimaStack reads a small set of Colima files directly so it can show useful profile details without invoking extra commands.

## Paths

Default paths are based on `$COLIMA_HOME`:

```txt
$COLIMA_HOME/<profile>/colima.yaml
$COLIMA_HOME/_templates/default.yaml
$COLIMA_HOME/ssh_config
$COLIMA_HOME/<profile>/daemon/daemon.log
```

## Configuration

Profile configuration is parsed from `colima.yaml` when available. Stored mounts are hydrated back into profile detail views from this file.

## Logs

Daemon logs are displayed in the workspace and Activity areas. Very large logs are capped in memory.
