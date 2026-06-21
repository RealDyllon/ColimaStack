---
title: Monitor
description: Inspect runtime CPU, memory, disk, network, capacity, and health signals.
---

`Monitor` is in the app sidebar under `Runtime`. It shows live usage and capacity for the selected running Colima profile.

![ColimaStack Monitor screenshot](/screenshots/monitor.png)

## How data appears

Monitor samples are collected when a selected Docker profile is running and backend inventory refresh succeeds. Samples are added by manual `Refresh` and by `Auto Refresh`.

Auto-refresh frequencies are:

- `Faster`: 2 seconds
- `Fast`: 5 seconds
- `Normal`: 10 seconds

The refresh loop skips while a command is active or the profile editor is open. Monitor history is capped at 90 samples per profile.

## Metrics shown

- `CPU used`: sum of Docker `stats --no-stream` CPU percentages.
- `Memory used`: sum of Docker stats memory usage.
- `Disk used`: sum of Docker `system df` sizes.
- `Network`: total I/O for the first sample, then receive/transmit rate between samples.
- `Block I/O`: read/write totals from Docker stats.
- `Capacity allocations`: configured CPU, memory, and disk ceilings for the selected profile.
- `Health signals`: running container count, number of running Colima profiles, command failures, Docker availability, and Kubernetes enabled/disabled state.

CPU is shown as usage against configured vCPU capacity. Memory and disk progress use configured profile allocation when available. Kubernetes metrics are collected for Kubernetes pages and backend metrics, but the Monitor usage sample is based on Docker stats and Docker disk usage.

## Empty states

- `Monitor unavailable`: diagnostics have not found a usable Colima setup.
- `No profile selected`: choose a profile first.
- `Live usage unavailable`: no runtime sample has been collected for the selected running profile.
- `No usage history yet`: wait for auto-refresh or click `Refresh`.

## Common reasons data is unavailable

- Selected profile is stopped.
- Selected profile is not a Docker runtime.
- Docker CLI is missing or cannot reach the selected context.
- Colima profile status has no Docker context/socket yet.
- Docker stats or disk usage commands fail.
- Tool lookup or `PATH` does not include the required CLI.

Use [Overview](/runtime/overview/) to confirm the selected context, and [Diagnostics](/features/diagnostics/) to inspect missing tools and runtime errors.
