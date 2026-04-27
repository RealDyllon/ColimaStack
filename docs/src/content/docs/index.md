---
title: ColimaStack
description: ColimaStack is a macOS app for Colima profiles, Docker inventory, Kubernetes visibility, diagnostics, and command feedback.
template: splash
sidebar:
  label: Overview
hero:
  title: '<img class="landing-wordmark" src="/brand/colimastack-logo-wordmark.png" alt="ColimaStack" />'
  tagline: A macOS workspace for local Colima profiles, Docker inventory, Kubernetes visibility, diagnostics, and command feedback.
  image:
    html: '<img class="landing-hero-image" src="/screenshots/overview.png" alt="ColimaStack overview dashboard showing profile status, runtime health, and backend resources." />'
  actions:
    - text: Start with Quick Start
      link: /quick-start/
      variant: primary
    - text: Install
      link: /install/
      variant: secondary
---

<section class="landing-intro">

ColimaStack is for developers who use [Colima](https://github.com/abiosoft/colima) as their local runtime and want a visible control surface for profiles, Docker resources, Kubernetes state, diagnostics, and recent command output.

</section>

<div class="landing-screens">
  <img src="/screenshots/containers.png" alt="ColimaStack Docker containers view with status, image, ports, and state columns." />
  <img src="/screenshots/kubernetes-cluster.png" alt="ColimaStack Kubernetes cluster view with node and cluster information." />
</div>

## What it covers

<div class="landing-grid">
  <article>
    <h3>Profiles</h3>
    <p>Create, select, start, stop, restart, update, edit, and delete local Colima profiles.</p>
  </article>
  <article>
    <h3>Docker inventory</h3>
    <p>Read containers, images, volumes, networks, stats, and disk usage from the selected Colima Docker context.</p>
  </article>
  <article>
    <h3>Kubernetes views</h3>
    <p>Inspect nodes, namespaces, pods, deployments, services, and metrics when Kubernetes is enabled on the selected profile.</p>
  </article>
  <article>
    <h3>Diagnostics</h3>
    <p>Check local <code>colima</code>, <code>docker</code>, <code>kubectl</code>, and <code>limactl</code> availability and runtime context errors.</p>
  </article>
</div>

## Start here

New users should read [Install](/install/) and [Quick Start](/quick-start/). Existing Colima users can usually open the app, select a profile, start it if needed, and verify resources in [Containers](/docker/containers/).

Core references: [Compatibility](/compatibility/), [Profiles](/profiles/overview/), [Monitor](/runtime/monitor/), [Menu Bar](/features/menu-bar/), [Diagnostics](/features/diagnostics/), [Security & Privacy](/security-privacy/), [Command API](/reference/command-api/), and [Troubleshooting](/troubleshooting/).
