---
title: Efficiency
description: How ColimaStack helps keep local runtime resource usage visible.
---

ColimaStack does not change Colima's resource model, but it makes the current allocation and runtime load easier to see.

## Profile resources

Each profile exposes its configured CPU, memory, and disk values. Use profile configuration to reduce allocations when a project does not need the default resources.

## Runtime stats

The Monitor view records runtime usage samples from Docker stats and Docker disk usage. This helps identify containers that are consuming unexpected CPU, memory, or disk.

## Idle profiles

Stop profiles when they are not needed. ColimaStack keeps lifecycle actions close to the resource views so cleanup does not require switching to a terminal.

## Disk usage

Use Images and Volumes to find large local artifacts. Docker system disk usage is included in backend snapshots where available.
