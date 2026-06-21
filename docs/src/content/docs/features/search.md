---
title: Search
description: Search local ColimaStack views and indexed runtime metadata.
---

ColimaStack search is local. The toolbar prompt changes by view, for example `Search containers`, `Search images`, `Search workloads`, or `Search activity`.

## What is searchable

View filtering searches the records currently shown by the selected view. It is trimmed, case-insensitive, diacritic-insensitive substring matching.

The backend search index includes:

- profiles
- Docker containers, images, volumes, and networks
- Kubernetes nodes, namespaces, pods, services, and deployments
- backend issues
- command history

Indexed tokens include names, IDs, statuses, contexts, labels, ports, image metadata, Kubernetes namespaces, node and pod details, issue text, and command output after redaction.

## Scope

Search covers local state already collected by ColimaStack. It does not search Docker registries, remote documentation, arbitrary local files, or Kubernetes resources beyond what the app has collected with `kubectl`.

Stopped profiles can be included in the backend index, but Docker and Kubernetes resource data appears only for the selected running profile when the relevant backend snapshot exists.

## Empty states

Search summary shows `No matches` or `<n> matches` and describes the current filter. If a page has no rows before search, use that page's empty-state guidance first.

## Refresh behavior

The index rebuilds after profile refreshes, backend snapshots, and command-log updates. Click `Refresh` or use `Auto Refresh` to collect newer resource state.

## Privacy

Search tokens are redacted for common secret patterns before indexing. See [Security & Privacy](/security-privacy/) for limitations.
