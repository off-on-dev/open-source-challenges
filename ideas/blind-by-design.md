# Adventure Idea: 🧪 Blind by Design

## Overview

**Theme:** A research lab is testing a vision-enhancement serum on volunteers. The serum is supposed to take ordinary eyes and produce sharper, even enhanced sight — useful for observation work. The lab is a Spring Boot service; OpenFeature is the chart system; `flags.json` decides what reading the lab records for each subject. The protocol is the same for every subject — what differs is the **observed `vision_state`**, because subjects come in with different biology, dose adherence, and trial-jurisdiction baseline. The flagship Phase 3 trial — a new amplifier algorithm — has started showing trouble: subjects stabilise slower, and roughly one in ten emerge blind. The dashboard that should be tracking all of this is dark, because the lab forgot to wire the metric exporter. Your mission across three levels: stand up the lab, read the chart by cohort, then turn on the lights and roll back the trial before more subjects lose their sight.

**Skills:**

- Wire OpenFeature into a real application and resolve flags from a flagd sidecar
- Layer per-request, per-process, and per-evaluation context so the same trial yields the right reading for every cohort, and audit every reading in the logs
- Roll out a risky algorithm in measured phases and roll it back from observability data when it misbehaves

**Technologies:** OpenFeature Java SDK, flagd, Spring Boot, Grafana LGTM (Tempo + Prometheus + Loki), Testcontainers

---

## Levels

### 🟢 Beginner: Stand up the lab

#### Description

Wire OpenFeature into a Spring Boot service so the lab's `vision_state` reading is resolved by a flagd sidecar against a `flags.json` instead of a hard-coded literal.

#### Story

The lab is on its first shift. Every subject who walks in gets the same hard-coded reading on their chart — no matter what the lab director just signed off on, no matter what the protocol says. A flagd sidecar is already running next to the lab in the Codespace, with an empty `flags.json` mounted into it; the OpenFeature SDK is not in the project at all. The lab director has approved the switch: add the SDK + flagd contrib provider to the project, register the provider against the sidecar, author the first flag definition in `flags.json`, and let the chart drive what gets recorded for each subject. While you are at it, prove the lab can change the reading without restarting anything — flagd's file watcher does the work.

#### The Problem

The Spring Boot starter app has a `Trial` controller whose `GET /` returns a string literal. There is no OpenFeature dependency in the `pom.xml`, no provider configured, and `flags.json` ships as `{"flags": {}}` so the flagd sidecar can boot. The participant must add the OpenFeature SDK and the flagd contrib provider, configure a `FlagdProvider` in `Resolver.RPC` mode (the devcontainer pre-sets `FLAGD_HOST=flagd` and `FLAGD_PORT=8013` so no host or port needs to be hard-coded), add the `vision_state` flag to `flags.json`, and switch the controller to call `client.getStringDetails` against it.

#### Objective

By the end of this level, the learner should:

- Have `curl http://localhost:8080/` return a `vision_state` reading **resolved by the flagd sidecar** (not the hard-coded `untreated` fallback)
- Confirm the response payload includes the OpenFeature evaluation details (variant, reason, value)
- Edit `flags.json` to change the `defaultVariant`, save, and have the **next** request return the new variant **without restarting the app or flagd**

#### What You'll Learn

- How an OpenFeature client and provider work together — the SDK is provider-agnostic and the flagd provider plugs in via dependency only
- What "remote provider" means in practice — the SDK calls a separate flag service (flagd) over gRPC; the SDK does not parse `flags.json` itself
- What `flags.json` looks like for flagd (state, variants, defaultVariant)
- Why hot-reload of the flag file matters operationally — configuration without redeploy

#### Tools & Infrastructure

- **Tools:** `curl`, `./mvnw`, `jq` (optional for prettier output)
- **Infrastructure:** Java 21 toolchain, a `flagd` sidecar service running in the devcontainer's compose stack on `:8013` (gRPC eval), `:8014` (management/metrics), `:8015` (sync), `:8016` (OFREP)

---

### 🟡 Intermediate: Outcome by cohort

#### Description

Add request-scoped context, a global runtime context, an invocation context at the call site, and an audit hook so the lab records the right reading per subject cohort and every reading shows up in the audit log.

#### Story

The trial is widening. Subjects from outside the lab's local population are getting the wrong reading on their chart, and the lab director has just walked into the lab holding a stack of complaint forms. The protocol is the same for every subject; what differs is the *observed outcome* because subjects come in with different biology, different dose adherence, and the trial is registered in different jurisdictions. The OpenFeature client never sees what **species** is on the table (each subject brings their own — humans, zyklops, you name it), never sees which **country** this trial is registered in (set once when the lab boots), never sees what **dose** the subject actually absorbed (varies per subject — missed appointments, fast metabolisers, the usual reasons). And there is no audit hook recording who ended up with which reading.

#### The Problem

The lab from the Beginner level reads the flag, but the same variant comes back for every request. The flag definition in `flags.json` already has all three targeting branches loaded — `species == zyklop`, improper-`dose` for non-zyklops, and `country == de` — but none of those attributes are in the evaluation context yet, so the targeting has nothing to fire on. The participant must wire a `SpeciesInterceptor` that lifts `?species=` into the OpenFeature **transaction context**, populate the **global** evaluation context with `country` from the `COUNTRY` env var at startup, pass a `dose` attribute as **invocation context** at the call site of `client.getStringDetails(...)`, and register an `AuditHook` that records every evaluation with the cohort attributes that drove it.

#### Objective

By the end of this level, the learner should:

- Have a Spring `HandlerInterceptor` (`SpeciesInterceptor`) that reads `?species=` from the request and sets it on the OpenFeature transaction context, then clears it on `afterCompletion`
- Have a global evaluation context that carries `country` from `System.getenv("COUNTRY")`, set once in `OpenFeatureConfig.@PostConstruct`
- Have the `Trial` controller pass a `dose` attribute as invocation context at the call site
- Have an `AuditHook` registered that emits one `[AUDIT] ...` log line per evaluation, at `WARN` for `clouded` outcomes
- Confirm `curl /?species=zyklop` returns `enhanced` (transaction wins), `curl /?dose=standard` with `COUNTRY=de` returns `sharp` (global), `curl /?dose=underdose` returns `clouded` (invocation), and `curl /?species=zyklop&dose=underdose` returns `enhanced` (precedence: species-zyklop is evaluated before improper-dose in `flags.json`)

#### What You'll Learn

- How OpenFeature's three evaluation-context layers compose — global (per-process), transaction (per-request, propagated thread-locally), invocation (per-evaluation, passed at the call site) — and how precedence works on conflict
- How transaction-context propagation works in a thread-per-request server with a `ThreadLocalTransactionContextPropagator`
- How hooks let you attach cross-cutting behaviour (audit today, observability tomorrow) without modifying every call site
- Why an audit log needs a fixed allowlist of context attributes — `targetingKey` and other PII routinely sit in the merged context in real apps

#### Tools & Infrastructure

- **Tools:** `curl`, `./mvnw`, `tail -f` against `app.log`, two convenience runners (`./run-germany.sh` and `./run-austria.sh`) that pre-set `COUNTRY` and tee to the log
- **Infrastructure:** Same Java 21 toolchain, the same `flagd` sidecar from Beginner (compose-managed alongside `workspace`)

---

### 🔴 Expert: Phase 3 — read the chart

#### Description

Finish wiring OpenTelemetry traces and metrics through to the Grafana LGTM stack, write a `ContextSpanHook` of your own that mirrors the merged evaluation context onto the active span, find the misbehaving Phase 3 amplifier in the dashboard, and roll it back without redeploying.

#### Story

The trial just went wide. The same flagd sidecar from earlier levels is now serving two flags that matter — the cohort-targeted `vision_state` from Intermediate, and a new fractional-rollout flag `vision_amplifier_v2` driving the Phase 3 trial. OpenTelemetry is half-wired: a traces exporter is shipping spans to Tempo, but the meter provider is unconfigured, so the rollout dashboard is dark. And the fractional bucket on `vision_amplifier_v2` is inverted — every subject is rolling into the new amplifier. Each evaluation under the new amplifier is 200 milliseconds slower to stabilise, and roughly one in ten subjects emerges blind (HTTP 500). The lab is the lab — it cannot fix what it cannot see. The dashboard is dark.

The director wants four things, in order: the dashboard lit up, the eval-context attributes that drove each outcome searchable on the spans (so on-call can answer "which dose got which variant?"), the bad fractional bucket identified, and the rollout rolled back to a safe number — all without redeploying the lab.

#### The Problem

The level ships a working lab pointed at the same `flagd` sidecar in `Resolver.RPC` mode, plus a Grafana LGTM container with OTLP receivers on the standard ports and a k6 loadgen that drives traffic when the `loadgen_active` flag is on. The OpenTelemetry SDK in the app is wired for traces (the OTel `TracesHook` is registered, the exporter writes to Tempo) but the meter provider's exporter is set to `none`, so the OpenFeature `MetricsHook` has nowhere to record. The `AuditHook` from Intermediate is carried over and continues to write a durable archive view; what the lab is missing is the **real-time correlation** between context attributes and span events. The participant must (1) flip `otel.metrics.exporter` from `none` to `otlp`, (2) register `MetricsHook` on the OpenFeatureAPI, (3) write a small `ContextSpanHook` that copies a fixed allowlist (`species`, `country`, `dose`) from the merged eval context onto the active span as `feature_flag.context.<key>`, (4) flip `loadgen_active` to `on` and observe the latency and 5xx panels, and (5) edit `flags.json` to flip the `vision_amplifier_v2` fractional bucket back to `100% off / 0% on` while the app keeps running.

#### Objective

By the end of this level, the learner should:

- Have `MetricsHook` registered and the OTel meter provider configured to export to the LGTM stack on `localhost:4317`
- Have a `ContextSpanHook` of their own that copies the merged evaluation context (`species`, `country`, `dose`) onto the active span as `feature_flag.context.<key>` — registered alongside `TracesHook` / `MetricsHook`
- Have **at least one trace** for `fun-with-flags-java-spring` visible in the Grafana **Explore → Tempo** view
- Have spans tagged with `feature_flag.context.dose=underdose` searchable in Tempo and lining up with `feature_flag.variant=clouded` on the same span
- Have the **Fun With Flags — Feature Flag Metrics** dashboard showing live evaluation rate, variant distribution, and latency by variant
- Have `vision_amplifier_v2` rolled back to `0% on`, confirmed by reading the flag from flagd's gRPC-Gateway HTTP route on `:8013`, and the HTTP 5xx rate dropping below threshold afterwards

#### What You'll Learn

- How the OpenFeature OTel hooks (`TracesHook` and `MetricsHook`) join flag evaluations to the rest of an app's telemetry without a separate ingestion path
- How to author your own `Hook` — a tiny class that reads `HookContext.getCtx()` (the merged eval context) and emits something useful (here: span attributes) — and why the **PII allowlist** matters when those attributes flow into observability backends with multi-day retention
- How fractional rollout in flagd buckets subjects by `targetingKey` and how to read the bucketing from a dashboard
- How a flag flip is a faster operational lever than a redeploy when a rollout is misbehaving

#### Tools & Infrastructure

- **Tools:** `curl`, `./mvnw`, `docker compose`, a browser pointed at Grafana on `:3000`
- **Infrastructure:** Java 21 toolchain, `flagd` sidecar (`:8013` gRPC eval, `:8014` management/metrics, `:8015` sync, `:8016` OFREP), `grafana/otel-lgtm` container on `:3000`/`:4317`/`:4318`/`:9090`/`:3200`, k6 loadgen container driving traffic when `loadgen_active` is on
