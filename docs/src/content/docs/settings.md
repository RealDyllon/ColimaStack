---
title: Settings
description: ColimaStack profile and app settings that affect runtime behavior.
---

Settings are split between app preferences and Colima profile configuration.

## App preferences

Current app-level behavior includes:

- selected workspace section
- selected profile
- automatic refresh
- refresh frequency
- command history retention
- profile log display

## Profile configuration

Profile settings map to `colima start` flags and Colima configuration files:

- runtime: Docker, containerd, or Incus
- VM type: QEMU, Virtualization.framework, or Krunkit
- architecture: host default, Apple Silicon, or Intel
- CPU, memory, and disk
- mount type and mount list
- DNS resolvers
- network mode and network interface
- port forwarder
- Kubernetes enablement and version
- k3s arguments and listen port
- Rosetta and nested virtualization options where supported

## Editing configuration

ColimaStack can open the profile editor and can also delegate to Colima's editor-backed flows for template and profile configuration.
