---
title: ColimaStack
description: ColimaStack is a native macOS control center for Colima profiles, Docker resources, and Kubernetes development clusters.
template: splash
sidebar:
  label: Overview
hero:
  title: '<img class="landing-wordmark" src="/brand/colimastack-logo-wordmark.png" alt="ColimaStack" />'
  tagline: A native macOS workspace for Colima profiles, Docker inventory, Kubernetes visibility, diagnostics, and command feedback.
  image:
    html: '<img class="landing-hero-image" src="/screenshots/overview.png" alt="ColimaStack overview dashboard showing profile status, runtime health, and backend resources." />'
  actions:
    - text: Start with Quick Start
      link: /quick-start/
      variant: primary
    - text: Browse Features
      link: /features/
      variant: secondary
---

<section class="landing-intro">

ColimaStack is built for developers who already trust [Colima](https://github.com/abiosoft/colima) as their local container runtime and want a faster way to see, inspect, and recover their environment. It keeps the Colima CLI as the foundation, then adds a focused product layer for daily profile, Docker, and Kubernetes work.

</section>

<div class="landing-screens">
  <img src="/screenshots/containers.png" alt="ColimaStack Docker containers view with status, image, ports, and age columns." />
  <img src="/screenshots/kubernetes-cluster.png" alt="ColimaStack Kubernetes cluster view with node and namespace health." />
</div>

## Built for the local runtime loop

<div class="landing-grid">
  <article>
    <h3>Profile-first control</h3>
    <p>Start, stop, inspect, and switch Colima profiles without turning routine runtime checks into terminal archaeology.</p>
  </article>
  <article>
    <h3>Docker inventory</h3>
    <p>Browse containers, images, volumes, networks, stats, and disk usage for the active Colima context.</p>
  </article>
  <article>
    <h3>Kubernetes awareness</h3>
    <p>Inspect nodes, namespaces, pods, deployments, services, and metrics when Kubernetes is enabled.</p>
  </article>
  <article>
    <h3>Actionable diagnostics</h3>
    <p>Spot missing or misconfigured <code>colima</code>, <code>docker</code>, <code>kubectl</code>, and <code>limactl</code> tools before they derail the session.</p>
  </article>
</div>

## Start here

Use the [Quick Start](/quick-start/) to get oriented, then check [Install](/install/) for dependency setup. If you are evaluating local runtime options, compare ColimaStack with [OrbStack](/compare/orbstack/), [Docker Desktop](/compare/docker-desktop/), and the [Colima CLI](/compare/colima-cli/).

This documentation reflects the launch surface currently represented in the app and release notes. Some pages document intended launch behavior that still requires final manual smoke testing with a live Colima installation.
