---
title: Profile Configuration
description: Configure Colima runtime, resources, mounts, networking, and Kubernetes options.
---

Profile configuration maps to `colima start` flags.

## Runtime

Choose the runtime Colima should use:

- Docker
- containerd
- Incus

## VM settings

Configure:

- VM type
- architecture
- CPU
- memory
- disk
- Rosetta where supported
- nested virtualization where supported

## Mounts

Configure mount type and mount list. Supported mount drivers in the app model include VirtioFS, SSHFS, and 9p.

## Networking

Configure DNS resolvers, network address support, network mode, network interface, and port forwarder.

## Kubernetes

Enable Kubernetes and optionally set a Kubernetes version, k3s arguments, and a k3s listen port.

## Advanced arguments

Additional arguments can be appended for advanced Colima flags not yet represented as first-class UI fields.
