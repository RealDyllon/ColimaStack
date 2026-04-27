---
title: SSH
description: Understand Colima SSH configuration access in ColimaStack.
---

ColimaStack can read Colima SSH configuration for a selected profile and uses Colima's SSH command shapes where implemented.

## SSH config

The app invokes:

```sh
COLIMA_PROFILE=<profile> colima ssh-config
```

It can also pass:

```sh
--layer=true
--layer=false
```

If command output is empty, the app can fall back to `$COLIMA_HOME/ssh_config` when present.

## SSH access

The command shape supported by source is:

```sh
COLIMA_PROFILE=<profile> colima ssh [--layer=true|false] [-- <command...>]
```

SSH access can mutate the VM depending on the command you run. Use [Activity and Logs](/features/activity/) to review command outcomes when exposed through app actions.

## Troubleshooting

- Confirm the profile exists and is selected.
- Confirm `colima` is available in [Diagnostics](/features/diagnostics/).
- Check profile files in [Files and Logs](/profiles/files/).
