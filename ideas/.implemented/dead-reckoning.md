# Adventure Idea: 🧭 Dead Reckoning

## Overview

**Theme:** The Grand Fleet's commission office is buried in complaints. Manifests are filed but nothing comes of them. Vessels that do sail arrive at port with the wrong cargo, and no one along the route can explain why. As the fleet's engineer, your mission is to restore order from keel to quayside and find out what the records are hiding.

**Skills:**

- Commission new services through an internal developer platform using software templates
- Debug and restore a broken end-to-end delivery pipeline across multiple platform tools
- Diagnose silent delivery failures in a distributed system using distributed tracing

**Technologies:** Backstage, Gitea, Argo Workflows, Argo CD, OpenTelemetry, Jaeger, Kubernetes

---

## Levels

### 🟢 Beginner: Laying the Keel

#### Description

Fix a broken Backstage software template so the commission office can register new vessels for service.

#### Story

The commission office has been open for weeks, but nothing is being processed: manifests are submitted, repositories never appear, and nothing makes it into the registry. Fix the broken Backstage software template so the office can start registering new vessels again.

#### The Problem

The vessel commissioning template is misconfigured. It is intended to scaffold a new service, create a repository in Gitea, and register the component in the Backstage catalog, but multiple issues prevent it from completing successfully.

#### Objective

- Successfully scaffold a new service using the vessel commissioning template with no errors
- See the new service appear as a registered component in the Backstage catalog
- Confirm a repository was created in Gitea containing the correct `catalog-info.yaml`

#### What You'll Learn

- How Backstage software templates are structured: parameters, steps, and output
- How scaffolder actions work (`fetch:template`, `publish:gitea`, `catalog:register`)
- How the catalog registration step connects a scaffolded repository to the Backstage catalog

#### Tools & Infrastructure

- **Tools:** Backstage UI, `kubectl`, `k9s`
- **Infrastructure:** Kubernetes Cluster, Backstage, Gitea

---

### 🟡 Intermediate: Sea Trial

#### Description

Fix the broken integration points in the delivery pipeline so that commissioning a vessel in Backstage results in a running deployment.

#### Story

The office is back in business: manifests are filed, repositories created, components registered. But captains keep reporting the same problem: their vessels never actually sail. Somewhere between the commission office and the open water, the delivery pipeline is broken. Trace it end to end and find where it breaks.

#### The Problem

Several integration points between platform components are misconfigured. The connection between Gitea and the workflow engine, the workflow step ordering, and the Argo CD configuration each have issues that together prevent a commissioned service from running in the cluster.

#### Objective

- Commission a new service end-to-end: template run, Gitea repository created, Argo Workflow completes, Argo CD Application created and synced, service running in the cluster
- Confirm the service is healthy by accessing it directly
- Identify which component broke at each integration point by reading its logs or UI

#### What You'll Learn

- How webhooks connect git events to workflow engines
- How Argo Workflows orchestrate multi-step delivery pipelines
- How Argo CD's app-of-apps pattern manages dynamically created applications
- How to trace a silent failure across multiple platform components

#### Tools & Infrastructure

- **Tools:** Backstage UI, `kubectl`, `k9s`, Argo CD UI, Argo Workflows UI
- **Infrastructure:** Kubernetes Cluster, Backstage, Gitea, Argo Workflows, Argo CD

---

### 🔴 Expert: The Chronometer

#### Description

Repair the fleet's broken navigation log, then use the complete traces it produces to diagnose why vessels are arriving with the wrong provisions.

#### Story

The fleet is running, but something is wrong at the far end: vessels are arriving with the wrong provisions, even though every system reported a successful voyage. The telemetry instruments are dark: Backstage isn't emitting traces, and the ones that do appear are disconnected fragments. Fix the instrumentation first, then use the complete picture to find where the delivery went wrong.

#### The Problem

Two things are broken before the traces can even be read. Backstage is not emitting spans: its OpenTelemetry plugin is misconfigured in `app-config.yaml`, so nothing from the commission office reaches Jaeger. Once that is fixed, traces appear but are fragmented: the workflow is not propagating trace context in its calls, so the Argo Workflows and Argo CD spans are disconnected from the Backstage spans.

With a complete trace finally visible, the root cause becomes clear: a workflow step executes more than once due to a retry logic bug, and the repeated execution uses different parameters than the original. Every tool reported success. Only the full trace reveals what actually happened.

#### Objective

- Fix Backstage's OpenTelemetry configuration so the commission office emits spans to Jaeger
- Fix trace context propagation so the full delivery pipeline appears as a single connected trace
- Identify how and where the delivery pipeline produced incorrect service configuration by reading the complete traces
- Fix the workflow so each commissioning produces exactly one execution of every step with the correct parameters

#### What You'll Learn

- How to configure Backstage's OpenTelemetry plugin to emit traces
- How trace context propagation connects spans across system boundaries
- How distributed traces reveal causal chains that per-tool logs cannot: not just that something went wrong, but what data flowed through each step
- Why observability is qualitatively different from logging, and what it means to navigate by dead reckoning versus taking a fix

#### Tools & Infrastructure

- **Tools:** Backstage UI, `kubectl`, `k9s`, Jaeger UI
- **Infrastructure:** Kubernetes Cluster, Backstage, Gitea, Argo Workflows, Argo CD, OpenTelemetry Collector, Jaeger
