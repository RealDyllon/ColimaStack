---
title: SSH
description: Use Colima SSH configuration and SSH access from ColimaStack.
---

ColimaStack can read SSH configuration with:

```sh
colima ssh-config
```

It can also invoke SSH access through Colima:

```sh
colima ssh
```

## SSH config

The app can display the Colima SSH configuration document for the selected profile. This is useful when connecting editors, terminals, or automation to a profile.

## Layers

Colima supports layer-aware SSH configuration. ColimaStack models layer selection for SSH config and SSH commands where exposed by the backend.
