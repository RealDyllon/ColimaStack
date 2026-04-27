---
title: Files and Logs
description: Local Colima files that ColimaStack reads for profile configuration, SSH, and logs.
---

ColimaStack reads selected files under Colima home. It does not create a separate remote store for these documents.

## Paths

`COLIMA_HOME` is respected when set. Otherwise ColimaStack uses `~/.colima`.

| Purpose | Path |
| --- | --- |
| Profile configuration | `$COLIMA_HOME/<profile>/colima.yaml` |
| Default template | `$COLIMA_HOME/_templates/default.yaml` |
| SSH config | `$COLIMA_HOME/ssh_config` |
| Lima override | `$COLIMA_HOME/_lima/_config/override.yaml` |
| Daemon log | `$COLIMA_HOME/<profile>/daemon/daemon.log` |

## Configuration

The selected profile's configuration is parsed to populate editor values and mount rows where available. If the profile configuration file is missing, the app falls back to profile status/default values.

## Logs

The `Activity` and `Overview` pages show the selected profile's daemon log. If the file is missing, the app shows a message that no Colima daemon log was found at the expected path.

Displayed log text is redacted and capped to the last 200,000 characters. Process stdout/stderr streams are separately capped at 1,048,576 bytes.

See [Security & Privacy](/security-privacy/) for redaction details.
