# 🔴 Expert Solution Walkthrough: Phase 3 — read the chart

Four sub-tasks, in order: wire the meter provider, register `MetricsHook`,
write and register a `ContextSpanHook` of your own, roll the bad flag back.
We'll do them exactly that way.

> ⚠️ **Spoiler Alert:** This walkthrough contains the full solution. Try
> solving it on your own first.

## 📋 Step 1: Read the objective

> By the end of this level, you should have:
>
> - The OpenTelemetry meter provider wired and the OpenFeature `MetricsHook` registered
> - A `ContextSpanHook` of your own that copies the merged evaluation context
>   (`species`, `country`, `dose`) onto the active span as `feature_flag.context.<key>`
> - At least one trace for service `fun-with-flags-java-spring` visible in Tempo
> - Spans tagged with `feature_flag.context.dose=underdose` searchable in Tempo
> - The `feature_flag_evaluation_requests_total` counter non-zero in Prometheus
> - The `vision_amplifier_v2` fractional rollout flipped back to 100% off / 0% on
> - HTTP 5xx rate over the last minute below 1%

## 🔍 Step 2: Inspect what's already wired

Traces work out of the box — the `TracesHook` is registered in
`OpenFeatureConfig.java` and the OTel SDK is exporting via OTLP/gRPC to the
LGTM container at `http://localhost:4317`. Open Grafana → Explore → Tempo →
search for `service.name=fun-with-flags-java-spring` and you should already
see traces. (If you don't, hit `curl http://localhost:8080/` a few times to
generate some.)

The metrics half, however, is dead. Two reasons:

1. `application.properties` has `otel.metrics.exporter=none`. The SDK creates
   a `SdkMeterProvider` but no exporter is attached, so any counter it
   records is dropped.
2. `OpenFeatureConfig.initProvider()` registers `TracesHook` but not
   `MetricsHook`. Even if the meter provider could export, no one is
   recording flag evaluations as metrics.

One thing that **is** already wired and matters for this level: the
`SpeciesInterceptor` you wrote in Intermediate. Expert ships it byte-for-byte
unchanged. The relevant part for this level is the line you already wrote
that reads `?userId=…` from the query string and constructs
`new ImmutableContext(userId, attributes)` — by SDK convention, the first
`String` argument **is** the OpenFeature `targetingKey`. That is what makes
the `vision_amplifier_v2` fractional rollout actually bucket per subject;
without it, every evaluation would hash the same way and the percentages
would do nothing. (Intermediate didn't have a flag that used the
targetingKey, so the wiring sat dormant; this is where it pays off.) You
don't write any new code for this in Expert — the rollback in Step 6 takes
effect immediately because the loadgen sends a fresh `userId` per request
into the interceptor you already shipped.

## 🛠 Step 3: Wire the meter provider

Open `src/main/java/dev/openfeature/demo/java/demo/OpenTelemetryConfig.java`.
Change the default for `otel.metrics.exporter` from `"none"` to `"otlp"`, and
add a default for `otel.metric.export.interval` so the meter flushes every
ten seconds. The full method:

```java
@Bean
public OpenTelemetry openTelemetry(
        @Value("${otel.service.name:fun-with-flags-java-spring}") String serviceName,
        @Value("${otel.exporter.otlp.endpoint:http://localhost:4317}") String otlpEndpoint,
        @Value("${otel.exporter.otlp.protocol:grpc}") String otlpProtocol,
        @Value("${otel.traces.exporter:otlp}") String tracesExporter,
        @Value("${otel.metrics.exporter:otlp}") String metricsExporter,
        @Value("${otel.logs.exporter:none}") String logsExporter,
        @Value("${otel.metric.export.interval:10000}") String metricExportInterval) {
    System.setProperty("otel.service.name", serviceName);
    System.setProperty("otel.exporter.otlp.endpoint", otlpEndpoint);
    System.setProperty("otel.exporter.otlp.protocol", otlpProtocol);
    System.setProperty("otel.traces.exporter", tracesExporter);
    System.setProperty("otel.metrics.exporter", metricsExporter);
    System.setProperty("otel.logs.exporter", logsExporter);
    System.setProperty("otel.metric.export.interval", metricExportInterval);

    autoConfigured = AutoConfiguredOpenTelemetrySdk.builder()
            .setResultAsGlobal()
            .build();
    return autoConfigured.getOpenTelemetrySdk();
}
```

Then update `src/main/resources/application.properties` to match:

```properties
spring.application.name=demo

otel.exporter.otlp.endpoint=http://localhost:4317
otel.exporter.otlp.protocol=grpc
otel.traces.exporter=otlp
otel.metrics.exporter=otlp
otel.logs.exporter=none
otel.service.name=fun-with-flags-java-spring
otel.metric.export.interval=10000
```

> The autoconfigure module reads `otel.metrics.exporter` and, when set to
> `otlp`, attaches an `OtlpGrpcMetricExporter` to the `SdkMeterProvider`. The
> resulting `OpenTelemetry` bean now exposes a working `getMeterProvider()`.

## 🛠 Step 4: Register `MetricsHook` on the OpenFeature API

Open `OpenFeatureConfig.java`. Inject the `OpenTelemetry` bean via
constructor injection and add `MetricsHook` next to the existing
`TracesHook` call:

```java
import dev.openfeature.contrib.hooks.otel.MetricsHook;
import dev.openfeature.contrib.hooks.otel.TracesHook;
import io.opentelemetry.api.OpenTelemetry;

@Configuration
public class OpenFeatureConfig implements WebMvcConfigurer {

    private final OpenTelemetry openTelemetry;

    public OpenFeatureConfig(OpenTelemetry openTelemetry) {
        this.openTelemetry = openTelemetry;
    }

    @PostConstruct
    public void initProvider() {
        OpenFeatureAPI api = OpenFeatureAPI.getInstance();
        FlagdOptions flagdOptions = FlagdOptions.builder()
                .resolverType(Config.Resolver.RPC)
                .build();
        api.setProviderAndWait(new FlagdProvider(flagdOptions));

        HashMap<String, Value> attributes = new HashMap<>();
        attributes.put("country", new Value(Optional.ofNullable(System.getenv("COUNTRY")).orElse("")));
        api.setEvaluationContext(new ImmutableContext(attributes));

        api.addHooks(new AuditHook());          // already wired in broken state
        api.addHooks(new TracesHook());         // already wired in broken state
        api.addHooks(new MetricsHook(openTelemetry));  // <-- you add this
        api.addHooks(new ContextSpanHook());           // <-- you add this
    }

    // addInterceptors(...) unchanged
}
```

### The `ContextSpanHook`

A small `Hook` of your own, in a new file `ContextSpanHook.java`, that mirrors the merged evaluation context onto the active span. This is what lets Tempo show "this request had `dose=underdose` and got `variant=clouded`" on the same span.

```java
package dev.openfeature.demo.java.demo;

import dev.openfeature.sdk.EvaluationContext;
import dev.openfeature.sdk.Hook;
import dev.openfeature.sdk.HookContext;
import dev.openfeature.sdk.Value;
import io.opentelemetry.api.trace.Span;

import java.util.List;
import java.util.Map;
import java.util.Optional;

public class ContextSpanHook implements Hook {

    private static final List<String> TRACKED = List.of("species", "country", "dose");

    @Override
    public Optional<EvaluationContext> before(HookContext ctx, Map hints) {
        Span span = Span.current();
        EvaluationContext ec = ctx.getCtx();
        for (String key : TRACKED) {
            Value v = ec.getValue(key);
            if (v != null && v.asString() != null) {
                span.setAttribute("feature_flag.context." + key, v.asString());
            }
        }
        return Hook.super.before(ctx, hints);
    }
}
```

Three notes worth calling out:

- `HookContext.getCtx()` returns the **merged** evaluation context — global + transaction + invocation, in that precedence order. So the hook reads whatever the SDK is about to use, regardless of which layer set the value.
- `Span.current()` returns the no-op span if there is no active OTel context (e.g. in tests without an instrumented HTTP server). `setAttribute` on the no-op span is a safe no-op, so the hook does not need defensive guards.
- **`TRACKED` is a fixed allowlist on purpose — do not iterate.** The merged context typically also carries `targetingKey` (often a stable user id) and, in real apps, things like `email`, account ids, or device identifiers. If you replace the allowlist with `for (String key : ec.asMap().keySet())` you ship that PII straight into Tempo / Prometheus, where it is retained for days and is hard to redact after the fact. Pick the minimum set of keys that helps you correlate, document why each is safe for long-term storage, and add new keys deliberately. The OpenTelemetry [security & privacy guidance](https://opentelemetry.io/docs/security/) covers the broader principle.

Restart the lab:

```bash
./mvnw spring-boot:run
```

After it boots, hit `curl http://localhost:8080/` a few times. Wait ten to
fifteen seconds and check Prometheus:

```bash
curl -s 'http://localhost:9090/api/v1/query?query=feature_flag_evaluation_requests_total' | jq
```

You should see entries with `feature_flag_key` labels for `vision_state`,
`vision_amplifier_v2`, and `loadgen_active`. The dashboard panels in Grafana
will start drawing within the next refresh interval.

## 🛠 Step 5: Turn on the loadgen and read the chart

Open `flags.json` and flip `loadgen_active`:

```json
"loadgen_active": {
  "state": "ENABLED",
  "variants": { "off": false, "on": true },
  "defaultVariant": "on"
}
```

Save. The k6 loadgen polls flagd every two seconds and starts hammering. Now
open Grafana → **Dashboards → Fun With Flags — Feature Flag Metrics**.
You'll see:

- **Evaluations per second** — three flag keys, all live
- **Variant distribution** — `vision_amplifier_v2` is heavily skewed toward `on`
- **HTTP latency** — sitting around 200ms, well above baseline
- **HTTP 5xx rate** — around 10%

## 🛠 Step 6: Roll the rollout back

The fractional bucket for `vision_amplifier_v2` is inverted. Edit `flags.json`:

```diff
 "vision_amplifier_v2": {
   "state": "ENABLED",
   "variants": { "off": false, "on": true },
   "defaultVariant": "off",
   "targeting": {
     "fractional": [
-      ["off", 0],
-      ["on", 100]
+      ["off", 100],
+      ["on", 0]
     ]
   }
 }
```

Save. flagd reloads within a second. The k6 script generates a fresh
`userId` per request, so the next request is immediately bucketed into
`off`. The dashboard panels recover within seconds.

## ✅ Step 7: Verify

Run the verifier:

```bash
adventures/planned/00-blind-by-design/expert/verify.sh
```

All eight checks should pass (lab reachable, flagd reachable, LGTM
reachable, `vision_amplifier_v2` rolled back, Prometheus has the metric
counter, Tempo has traces, Tempo spans carry the `feature_flag.context.*`
attribute, 5xx rate below threshold). The 5xx rate check tolerates a brief
tail of errors from before the rollback, but if you wait a minute it
settles to zero.

## 🎓 What this exercise demonstrates

- **Decoupling deployment from release.** Once the flag is in place, rolling
  out and rolling back happen via a JSON edit, not a redeploy. That is the
  same lever you would pull at 3am when the new pricing engine starts
  erroring.
- **Stable bucketing via `targetingKey`.** The k6 script generates a fresh
  `userId` per request *on purpose* — it lets us see the rollback take
  effect immediately. In a real app, the `userId` is the logged-in user, so
  the bucketing is sticky across the user's session and the rollback only
  helps users who arrive *after* the flag flip.
- **Two halves of OTel observability.** Traces tell you about a specific
  request; metrics tell you about the population. The OpenFeature OTel
  hooks expose both for flag evaluations using the same OTel SDK the rest of
  the app already exports through.
