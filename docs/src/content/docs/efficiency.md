---
title: Efficiency
description: Use ColimaStack views to identify local runtime allocation and usage.
---

ColimaStack does not change Colima's resource model. It makes configured allocation and Docker-reported usage visible for the selected profile.

## Profile resources

`Overview`, `Profiles`, and `Monitor` show configured CPU, memory, and disk values when Colima status/configuration provides them. Change allocations from the profile editor.

## Runtime stats

`Monitor` builds samples from Docker stats and Docker disk usage:

- CPU percent
- memory usage
- disk usage from `docker system df`
- network receive/transmit totals and rates
- block read/write totals
- running container count

Monitor history is capped at 90 samples per profile.

## Idle profiles

Stopped profiles do not populate Docker or Kubernetes backend snapshots. Use `Profiles`, the toolbar, or the menu bar to stop profiles that are not needed.

## Disk usage

Use `Images`, `Volumes`, and `Monitor` to inspect image records, Docker-managed volumes, profile mounts, and Docker disk usage. Cleanup still happens through Docker/Colima CLI commands outside the current app UI.
