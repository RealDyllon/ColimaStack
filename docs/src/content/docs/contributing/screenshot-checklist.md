---
title: Screenshot Checklist
description: Internal checklist for adding screenshots without exposing missing-image TODOs to users.
---

This checklist is for contributors. Do not add "missing screenshot" notes to public pages.

| Page | UI state to capture | Filename | Alt text |
| --- | --- | --- | --- |
| Overview | Running Docker profile with diagnostics and recent activity visible. | `/screenshots/overview.png` | ColimaStack Overview screenshot |
| Profiles | At least two profiles, one selected and one running. | `/screenshots/profiles.png` | ColimaStack Profiles screenshot |
| Docker Containers | Running sample container with published port. | `/screenshots/containers.png` | ColimaStack Containers screenshot |
| Docker Images | Several image rows with tags and sizes. | `/screenshots/images.png` | ColimaStack Images screenshot |
| Monitor | Running profile with at least two usage samples. | `/screenshots/monitor.png` | ColimaStack Monitor screenshot |
| Kubernetes Cluster | Kubernetes-enabled profile with a ready node. | `/screenshots/kubernetes-cluster.png` | ColimaStack Kubernetes Cluster screenshot |
| Kubernetes Workloads | Pods and deployments across namespaces. | `/screenshots/kubernetes-workloads.png` | ColimaStack Workloads screenshot |
| Diagnostics | Tool checks populated with at least Colima and Docker available. | `/screenshots/diagnostics.png` | ColimaStack Diagnostics screenshot |
| Menu Bar | Selected running profile with Docker and Kubernetes menus available. | `/screenshots/menu-bar.png` | ColimaStack menu bar screenshot |

Existing public screenshot assets should be used where they match the current UI. Add new public assets only when the capture is accurate and the filename is stable.
