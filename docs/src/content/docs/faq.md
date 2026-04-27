---
title: Frequently Asked Questions
description: Common questions about ColimaStack, Colima, Docker contexts, and Kubernetes support.
---

## Is ColimaStack a replacement for Colima?

No. ColimaStack is a native macOS app for managing and observing Colima. Colima remains the runtime provider.

## Does ColimaStack include Docker?

No. Install the Docker CLI separately. ColimaStack uses Docker commands to read containers, images, volumes, networks, stats, and disk usage from the selected Colima context.

## Do I need Docker or kubectl installed?

Not for core Colima profile management. Install the Docker CLI only for Docker runtime inventory, and install `kubectl` only for Kubernetes inventory and context checks.

## Can I use multiple Colima profiles?

Yes. ColimaStack lists profiles and scopes operations through `COLIMA_PROFILE`. Docker context names are derived from the selected profile.

## Does Kubernetes work?

ColimaStack supports Colima's Kubernetes lifecycle toggle and Kubernetes inventory views. Metrics depend on the cluster having metrics support available.

## Can I still use the terminal?

Yes. ColimaStack is designed to keep CLI behavior visible. It surfaces command activity, output, logs, and recovery messages so the GUI does not become a black box.

## Is this the same kind of product as OrbStack?

It is adjacent, but not identical. OrbStack bundles its own Docker, Kubernetes, Linux machine, networking, and app experience. ColimaStack builds a polished GUI and observability layer around the open-source Colima toolchain.
