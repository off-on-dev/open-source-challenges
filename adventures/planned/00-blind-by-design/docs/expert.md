# 🔴 Expert: Phase 3 — read the chart

Three sub-tasks:

1. **Wire the OpenTelemetry meter provider** and register the OpenFeature `MetricsHook` so flag evaluations show up as Prometheus counters.
2. **Author a `ContextSpanHook`** of your own — a small `Hook` that copies the merged evaluation context (`species`, `country`, `dose`) onto the active OTel span as `feature_flag.context.<key>` so traces correlate variants with the context that drove them.
3. **Diagnose and roll back a misbehaving fractional rollout.** The `vision_amplifier_v2` flag is at 100% on; it's adding 200ms latency and a 10% HTTP 5xx rate. Identify it on the Grafana dashboard and roll it back via `flags.json` — no redeploy.

Spans are already flowing into Tempo from the OpenFeature `TracesHook`, but the metrics half is dead — the `MeterProvider` has no exporter and the `MetricsHook` was never registered. The dashboard the operator wants to triage from is empty. The k6 loadgen is idle, waiting for a flag flip to turn it on.

The level passes when (a) `feature_flag_evaluation_requests_total` is non-zero in Prometheus, (b) Tempo spans for `fun-with-flags-java-spring` carry `feature_flag.context.*` attributes, (c) `vision_amplifier_v2` is rolled back to 100% off, and (d) the HTTP 5xx rate over the last minute is below 1%.

## 🧪 The story (optional)

The trial just went wide. Phase 3 of the new vision amplifier — `vision_amplifier_v2` — was approved for the full cohort yesterday morning. The promise was straightforward: subjects emerge with sharper eyesight than they walked in with. By mid-afternoon the audit log was screaming. Subjects were stabilising 200ms slower, and roughly one in ten of them was emerging **blind** — containment failure recorded as an HTTP 500. The lab director pulled up the **Feature Flag Metrics** dashboard expecting to triage visually. The dashboard was dark. Someone had wired up traces but never finished the metrics half. There is no chart to read. The lab is studying eyesight and the lab itself cannot see.

Your job, in order: **turn on the lights**, find the bad arm of the trial, and **halt enrolment** on the amplifier — all without redeploying the lab. That last constraint is the whole point of feature flags: when a rollout starts misbehaving in production, you need an operational lever that does not take twenty minutes to pull. Save the file, watch the dose drop, watch the 5xx rate fall back to baseline, watch the next batch of subjects walk out seeing.

## ⏰ Deadline

Coming Soon
> ℹ️ You can still complete the challenge after this date, but points will only
> be awarded for submissions before the deadline.

## 📝 Solution Walkthrough

> ⚠️ **Spoiler Alert:** The following walkthrough contains the full solution
> to the challenge. We encourage you to try solving it on your own first.
> Consider coming back here only if you get stuck or want to check your
> approach.

If you get stuck, follow the
[step-by-step solution walkthrough](./solutions/expert.md).

## 💬 Join the discussion

Share your solutions and questions in the
[challenge thread](https://community.open-ecosystem.com/c/open-ecosystem-challenges/)
in the Open Ecosystem Community.

## 🏗️ Architecture

Four containers and one Spring Boot process, all on a shared Docker network.

```
┌──────────────────────┐      OTLP/gRPC :4317      ┌────────────────────────┐
│  Spring Boot         │ ────────────────────────▶ │  grafana/otel-lgtm     │
│  fun-with-flags-     │      flag eval + HTTP     │   - Grafana   :3000    │
│  java-spring         │                           │   - Prometheus :9090   │
│  :8080               │                           │   - Tempo     :3200    │
└─────┬────────────────┘                           └─────────▲──────────────┘
      │ OpenFeature SDK :8013                                │ scrape / pull
      │ (RPC mode)                                           │
┌─────▼────────────────┐                           ┌─────────┴──────────────┐
│  flagd               │ ◀──── poll loadgen flag ──│  k6 loadgen            │
│  :8013 (gRPC + HTTP  │                           │  HTTP GET /?userId=…   │
│         eval gateway)│                           │  (the lab interceptor  │
│  :8014 management /  │                           │   sets userId as the   │
│        metrics       │                           │   targetingKey, which  │
│  :8015 sync stream   │                           │   is what fractional   │
│  :8016 OFREP         │                           │   rollouts bucket on)  │
│  flags.json mounted  │                           │                        │
└──────────────────────┘                           └────────────────────────┘
```

## 🎯 Objective

By the end of this level, you should have:

- The OpenTelemetry **meter provider** wired and the OpenFeature **`MetricsHook`** registered
- Verified: the **`SpeciesInterceptor`** carried over from Intermediate is wiring `?userId=` as the OpenFeature **`targetingKey`** on every request, so the `vision_amplifier_v2` fractional rollout buckets per subject rather than landing every request in the same bucket *(you don't write this — verify it via the dashboard's variant-distribution panel after step 5)*
- A **`ContextSpanHook`** of your own — a small `Hook` that copies the merged evaluation context (`species`, `country`, `dose`) onto the active span as `feature_flag.context.<key>` — registered alongside `TracesHook`/`MetricsHook`
- **At least one trace** for service `fun-with-flags-java-spring` visible in Tempo
- Spans tagged with **`feature_flag.context.dose=underdose`** searchable in Tempo and lining up with `feature_flag.variant=clouded` on the same span
- The **`feature_flag_evaluation_requests_total`** counter non-zero in Prometheus
- The **`vision_amplifier_v2`** fractional rollout flipped back to **100% off / 0% on**
- The HTTP 5xx rate over the last minute below **1%**

## 📚 Concepts you'll touch

If you came in fresh on OpenTelemetry SDK plumbing or flagd's fractional rule, read this section first.

### OpenTelemetry **TracerProvider** vs **MeterProvider**

Spans are per-request timing (one trace per HTTP call, with nested events), counters are aggregate population stats (rate of evaluations across all requests, distribution of variants). In this lab the trace half is wired and Tempo already shows spans; the metrics half is dead and the dashboard is dark — that's the gap you close.

OTel ships two parallel pipelines, one for **traces** (spans, distributed timing) and one for **metrics** (counters, histograms). Each has its own provider, its own SDK, its own exporter. In this level the `TracerProvider` is already wired (spans are flowing into Tempo). The `MeterProvider` is not — that is your fix. Both providers register globally via `GlobalOpenTelemetry`, so once you wire the meter, the OpenFeature `MetricsHook` finds it without any further plumbing.

### OpenFeature `TracesHook` and `MetricsHook`

The OpenFeature OTel contrib library ships two hooks that turn every flag evaluation into telemetry:

- **`TracesHook`** — emits a span event (`feature_flag.evaluation`) on the active span with `feature_flag.key`, `feature_flag.variant`, and `feature_flag.reason` attributes. This is why flag evaluations show up nested inside HTTP request spans in Tempo.
- **`MetricsHook`** — emits four counters per evaluation: `feature_flag_evaluation_requests_total`, `_success_total`, `_error_total`, and an active-count up/down counter. These power the dashboard panels.

Both hooks need a global `OpenTelemetry` instance. The `TracesHook` works once you have a `TracerProvider`; the `MetricsHook` needs a `MeterProvider`.

### Authoring your own hook to enrich spans with context

The `AuditHook` carried over from Intermediate already records the same context attributes (species / country / dose) into a durable `[AUDIT]` log line — that is the safety officer's tool, useful weeks later for forensic follow-up. What it does not give you is **real-time correlation in the dashboard**: log lines do not show up alongside `feature_flag.variant` on a Tempo span. So `TracesHook` is great at recording **what** happened (the variant, the reason), `AuditHook` records the audit-archive view, and there is still a gap — the evaluation context attributes that drove the decision are not on the span. The two hooks stay; you add a third for the on-call's view.

The OpenFeature `Hook` interface is the right place to fix that. The shape is roughly:

```text
before(hookCtx) {
    span = active OTel span
    for each allowlisted key in merged eval context:
        span.setAttribute("feature_flag.context." + key, value)
}
```

The `before` hook receives a `HookContext` whose `getCtx()` returns the **merged** evaluation context (global + transaction + invocation), which is exactly what drove the flag's resolution — so the attributes you copy off it line up with what the variant decision actually saw. Span attributes go on `Span.current()` because that is the active HTTP request span; the OpenFeature hook fires inside that span's scope.

Register it next to `TracesHook` / `MetricsHook` in `OpenFeatureConfig`. Now every flag evaluation tags its parent span with the context attributes the lab cares about. In Tempo: **Search → Service: fun-with-flags-java-spring → +Tag → `feature_flag.context.dose=underdose`** lights up exactly the requests where a tech mis-dosed, with the resolved variant on the same span event.

The full implementation, including imports and a couple of subtle correctness notes, is in [solutions/expert.md](./solutions/expert.md).

> ⚠️ **Allowlist, don't iterate.** Use a fixed allowlist for the same reason the `AuditHook` does — see [Intermediate's PII note](./intermediate.md#3c-an-audithook) and the [OpenTelemetry security guidance](https://opentelemetry.io/docs/security/).

### `flagd` `fractional` operation + `targetingKey`

`fractional` is flagd's bucketing operation. Given a list of `[variant, percent]` pairs, it deterministically assigns each evaluation to one variant based on a hash of the **targeting key** on the evaluation context. Same key → same bucket → same variant, every request. Different keys spread across the percentages. **If no targeting key is set, every evaluation hashes the same way and the rollout collapses — every request lands in the same bucket and the percentages do nothing.**

You already wired this up in Intermediate. The **`SpeciesInterceptor`** you wrote there reads `?userId=...` from each request and constructs an `ImmutableContext(userId, attributes)` — by SDK convention the first `String` argument to `ImmutableContext` **is** the OpenFeature `targetingKey`. Expert ships the same interceptor byte-for-byte; the lab is already serving fractional rollouts correctly without you touching it. (Intermediate didn't have a flag that used the targetingKey; this is where it pays off.)

The k6 loadgen demonstrates this end-to-end: it generates a fresh random `userId` per request, which means the interceptor produces a different targeting key per request, which means the fractional rollout spreads across the percentages exactly as configured. The dashboard's variant-distribution panel reflects that split directly.

## 🧠 What You'll Learn

- How the OpenFeature OpenTelemetry hooks (`TracesHook` and `MetricsHook`) join
  flag evaluations to the rest of an application's telemetry without a
  separate ingestion path
- How to **author your own `Hook`** — a tiny class that copies merged-eval-context
  attributes onto the active OTel span — to close the loop between *why* a
  flag resolved the way it did and *what* the operator sees in Tempo
- How [`fractional`](https://flagd.dev/reference/custom-operations/fractional-operation/)
  rollout in flagd buckets users by `targetingKey` — same key, same bucket, every
  request — and how to read that bucketing off a dashboard
- How a **flag flip** is a faster operational lever than a redeploy when a
  rollout is misbehaving — the difference between a one-line config change and
  a twenty-minute deployment

## 🧰 Toolbox

Your Codespace comes pre-configured with the following tools:

- [`curl`](https://curl.se/): HTTP client for hitting the lab, flagd, and Prometheus
- [`./mvnw`](https://maven.apache.org/wrapper/): The Maven wrapper to build and run the Spring Boot lab
- A browser pointed at [`http://localhost:3000`](http://localhost:3000) for Grafana (admin / admin)
- [`jq`](https://jqlang.github.io/jq/): Pretty-print and filter JSON from `curl`

flagd, the Grafana LGTM stack, and the k6 loadgen are **sibling devcontainer services** — they come up automatically when the Codespace boots. There is no `docker compose up` step. Inside the workspace they are reachable as `flagd`, `lgtm`, and `loadgen`; on the host they are forwarded to the same `localhost:NNNN` ports that `verify.sh` and the docs assume.

## ✅ How to Play

### 1. Start Your Challenge

> 📖 **First time?** Check out the [Getting Started Guide](../../start-a-challenge)
> for detailed instructions on forking, starting a Codespace, and waiting for
> infrastructure setup.

Quick start:

- Fork the repo
- Create a Codespace
- Select **"Adventure 00 | 🔴 Expert (Phase 3 — read the chart)"**
- Wait ~2-3 minutes for the sibling containers (flagd, Grafana LGTM, k6
  loadgen) to come up. They are part of the devcontainer compose, so they
  start automatically — no `docker compose up` step.
- Once the IDE attaches to the workspace, start the Spring Boot lab. Click
  **Run** on `Laboratory` in the Spring Boot Dashboard panel (or press
  **F5** with `Laboratory.java` open), or run `./mvnw spring-boot:run`
  from the integrated terminal.

### 2. Access the UIs

Open the **Ports** tab in the bottom panel and click through to:

#### Spring Boot lab (Port `8080`)

The application under test. Open `http://localhost:8080/` to get a vision_state reading
back. Add a `userId` query parameter (e.g. `?userId=subject-42`) to give the
fractional rollout a stable bucketing key.

#### Grafana (Port `3000`)

The single window into the LGTM stack. Login is `admin` / `admin` (skip the
"change your password" prompt).

- **Dashboards → Fun With Flags — Feature Flag Metrics** — the dashboard the
  director keeps reloading. Empty for now.
- **Explore → Tempo** — search by service `fun-with-flags-java-spring`
  to see flag evaluations as span events nested inside HTTP request spans.
  Traces work even before you wire up metrics.

#### Prometheus (Port `9090`)

Exposed by the LGTM container. Useful for `curl`-driven debugging:
`curl 'http://localhost:9090/api/v1/query?query=feature_flag_evaluation_requests_total'`.

#### Tempo (Port `3200`)

Tempo's own HTTP API. The `verify.sh` script uses
`http://localhost:3200/api/search?tags=service.name=fun-with-flags-java-spring`
to assert traces are flowing.

#### flagd

flagd is on `:8013` (gRPC eval) — same as Beginner; the other ports (`8014` management/metrics, `8015` sync, `8016` OFREP) aren't used in this level.

#### OTLP receivers (Ports `4317` / `4318`)

The Spring Boot app exports traces (and, after you finish the wiring, metrics)
to the LGTM stack on `4317` (gRPC) and `4318` (HTTP).

### 3. Implement the Objective

There are three sub-tasks, in order:

#### 3a. Wire the OpenTelemetry meter provider

Open
`adventures/planned/00-blind-by-design/expert/src/main/java/dev/openfeature/demo/java/demo/OpenTelemetryConfig.java`.
The `@Bean` method already calls `AutoConfiguredOpenTelemetrySdk.builder()`,
which produces an `OpenTelemetry` instance with **both** a `SdkTracerProvider`
and a `SdkMeterProvider` — but only the tracer provider has an exporter.
The meter provider is told `otel.metrics.exporter=none`, so any metrics it
records go nowhere.

Flip `otel.metrics.exporter` to `otlp` so the SDK attaches an
`OtlpGrpcMetricExporter`. The cleanest way is to update both the default in
`OpenTelemetryConfig.java` and the value in
`src/main/resources/application.properties`. While you're there, set
`otel.metric.export.interval=10000` so the dashboard updates within ten
seconds of new traffic instead of waiting a minute.

#### 3b. Register `MetricsHook(OpenTelemetry)` on the OpenFeature API

Open `OpenFeatureConfig.java`. The `TracesHook` is already registered;
`MetricsHook` is not. `MetricsHook` needs the `OpenTelemetry` instance to grab
the meter provider, so inject the bean via constructor injection and
`api.addHooks(new MetricsHook(openTelemetry));` next to the `TracesHook` call.

If you compile and run after this step, the **Fun With Flags — Feature Flag
Metrics** dashboard in Grafana stays empty — there is no traffic. Move on.

#### 3c. Turn on the loadgen, find the bad rollout, roll it back

Edit `flags.json` in the expert directory and flip `loadgen_active`'s
`defaultVariant` from `"off"` to `"on"`. flagd watches the file and picks up
changes within a second. The k6 loadgen container has been polling
`loadgen_active` every two seconds — it will notice and start hammering
`http://workspace:8080/` with five virtual users (the workspace service name resolves inside the compose network).

Now open the dashboard. When the loadgen turns on you should see latency creep up around 200ms and 5xx rate around 10%; if those don't move, the loadgen flag isn't actually live yet.

That's the diagnosis: the fractional rollout for `vision_amplifier_v2` is
inverted. The flag definition currently reads:

```json
"fractional": [
  ["off", 0],
  ["on", 100]
]
```

Edit `flags.json` again — flip the percentages so `off` gets `100` and `on`
gets `0`. Save. Within one or two seconds flagd reloads. Because the
`SpeciesInterceptor` is wiring `?userId=` through to the OpenFeature
`targetingKey` on every request, and the loadgen generates a fresh `userId`
per request, the fractional rollout responds immediately — every subject
re-buckets against the new percentages and the population moves to the safe
variant. Watch the latency p99 panel collapse back to baseline and the 5xx
rate fall to zero.

**No deploy. No rebuild. No restart of the lab.**

### 4. Verify Your Solution

Once the dashboard is healthy, run the verifier:

```bash
adventures/planned/00-blind-by-design/expert/verify.sh
```

The script asserts the lab, flagd, and LGTM are reachable, that
`vision_amplifier_v2` evaluates to `false` for a probe user, that the
`feature_flag_evaluation_requests_total` Prometheus counter is non-zero, that
Tempo has at least one trace for `fun-with-flags-java-spring`, and that the
HTTP 5xx rate over the last minute is below 1%.

If everything turns green, your solution is solid. 🎉
