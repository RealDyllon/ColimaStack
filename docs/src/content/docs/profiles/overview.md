---
title: Profiles
description: Work with Colima profiles from ColimaStack.
---

Profiles are the central unit of work in ColimaStack. Each profile has its own runtime state, configuration, Docker context, logs, and Kubernetes setting.

## Profile actions

ColimaStack supports:

- list
- status
- start
- stop
- restart
- update
- delete
- edit configuration
- start or stop Kubernetes

## Profile identity

The default profile uses Docker context `colima`. Named profiles usually use `colima-<profile>`.

Most profile-scoped commands are executed with `COLIMA_PROFILE` set to the selected profile.
