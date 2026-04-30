# 🟡 Intermediate: Outcome by cohort

Populate all three OpenFeature evaluation-context layers on a Spring Boot service and register a custom `Hook`:

- **Transaction context** (request-scoped) — populated by a Spring `HandlerInterceptor` that reads `?species=` and `?userId=`, and clears on `afterCompletion` so values don't leak across pooled threads.
- **Global context** (process-scoped) — set once at startup from the `COUNTRY` environment variable.
- **Invocation context** (call-site) — passed as a third argument to `client.getStringDetails(...)`, carrying the per-evaluation `dose` attribute.
- **Audit `Hook`** — fires after every flag evaluation, writes an `[AUDIT]` log line with a fixed PII-safe attribute allowlist.

The broken-state lab already has the SDK and flagd provider wired in `Resolver.RPC` mode. The targeting in `flags.json` already carries three branches — `species == zyklop`, improper-`dose` for non-zyklops, `country == de` — but none of those attributes are in the eval context yet, so every request lands on the default variant. Your job is to make the targeting fire by wiring the three context layers and the audit hook.

## 🧪 The story (optional)

The trial is widening. Subjects from outside the lab's local population are getting the wrong reading on their chart, and the lab director has just walked into the lab holding a stack of complaint forms. She wants the audit log to tell her, after the fact, exactly which `vision_state` the lab recorded for which subject — and she wants the lab to read the chart properly before it records any more bad readings.

The protocol is the same for every subject; the lab is not varying the trial. What differs is the **observed outcome**, because subjects don't all start from the same place — some have a biology that responds enhancedly to the same serum, some absorb less or more than the protocol's standard dose, and the trial is registered in different jurisdictions with different baselines.

Your shift: teach the lab to read each subject's species off the request, attach the trial's **country of registration** (set on the JVM via the `COUNTRY` environment variable) to the global context, pass the **dose** as invocation context at the moment of the flag evaluation, and register an audit hook that records every dose with its variant and reason.

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Spring Boot lab  (this challenge)                                   │
│                                                                      │
│  HTTP ──► SpeciesInterceptor ──► Trial ──► OpenFeature client        │
│           (transaction ctx:     (invocation ctx:   (global ctx:      │
│            species ← ?species=   dose ← computed   country ←         │
│            targetingKey          at call site,     $COUNTRY env)     │
│              ← ?userId=)         overridable                         │
│                                  with ?dose=)                        │
│                                                            │         │
│                                                            ▼         │
│                                                       AuditHook      │
│                                                       (audit log)    │
│                                                            │         │
│                                                            ▼         │
│                                                       FlagdProvider  │
│                                                       (Resolver.RPC) │
└────────────────────────────────────────────────────────────┬─────────┘
                                                             │  gRPC :8013
                                                             ▼
                                          ┌─────────────────────────────┐
                                          │   flagd  (sibling container) │
                                          │   reads + watches flags.json │
                                          └─────────────────────────────┘
```

The lab and a flagd sidecar run as siblings in the devcontainer's compose stack. The OpenFeature client uses `Resolver.RPC` to reach `flagd:8013`; flagd is the one watching `flags.json` and serving evaluations from it. The targeting rules live entirely inside `flags.json`; your job is to make sure the attributes the rules reference (`species`, `country`, `dose`) are populated on every evaluation.

## 🎯 Objective

By the end of this level, you should have:

- A Spring `HandlerInterceptor` that reads `?species=` from each incoming request, sets it on the OpenFeature **transaction context** for the duration of the request, and clears it on completion
- The same interceptor reads `?userId=` and sets it as the OpenFeature **`targetingKey`** — no Intermediate flag uses it yet, but it's the bucketing key for any fractional rollout downstream (Expert's `vision_amplifier_v2` is the obvious one) and it's the canonical PII identifier the AuditHook deliberately won't log
- A **global evaluation context** that carries `country` from the `COUNTRY` environment variable (`System.getenv("COUNTRY")`) the lab was started with
- A `Trial` controller that, on each evaluation, passes the **`dose`** as **invocation context** — `"standard"` most of the time, `"underdose"` or `"overdose"` when the lab tech mis-measures (overridable with `?dose=`)
- A custom `Hook` registered on the OpenFeature API that logs every flag evaluation with the flag key, variant, and reason
- `curl /?species=zyklop` → `"enhanced"` — zyklop biology dominates regardless of dose or country
- `curl /?dose=standard` → `"sharp"` (with `COUNTRY=de`) — proper dose, country branch fires
- `curl /?dose=underdose` → `"clouded"` — improper dosing causes side effects in non-zyklop subjects
- `curl /?species=zyklop&dose=underdose` → `"enhanced"` — zyklop biology survives bad dosing
- The response is never the literal fallback `"untreated"`
- The application log shows at least one line emitted by your `AuditHook` per request

> 📋 **Run with `tee app.log`.** The verifier greps `[AUDIT]` lines from `app.log` next to `pom.xml`. The `./run-germany.sh` / `./run-austria.sh` scripts handle this for you; if you run `./mvnw spring-boot:run` directly, pipe through `| tee app.log` or the verifier has nothing to grep.

## 📚 Concepts you'll touch

- **Spring `HandlerInterceptor`** — per-request hook that runs `preHandle` before your controller and `afterCompletion` after the response. See [Spring's `HandlerInterceptor` Javadoc](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/servlet/HandlerInterceptor.html).
- **Three OpenFeature context layers** — *global* (set once at startup, every request sees it), *transaction* (request-scoped, cleared at `afterCompletion`), *invocation* (passed at the call site). They merge before evaluation; **invocation > transaction > global** on conflict.
  The transaction layer needs a **`ThreadLocalTransactionContextPropagator`** registered once on `OpenFeatureAPI` at startup — without it, the SDK has no way to carry per-request context across the call into the controller, and the transaction context silently stays empty.
- **`targetingKey`** — a special slot on the eval context that flag implementations use as the bucketing key for fractional rollouts. The SDK exposes it via `ec.getTargetingKey()` rather than `ec.getValue("targetingKey")`; the `ImmutableContext(targetingKey, attributes)` constructor sets it explicitly. In real apps it's typically a stable user id — i.e. the canonical PII identifier you do **not** want flowing into audit logs.
- **`Hook`** — interceptor for flag evaluations. `before`/`after`/`error`/`finallyAfter` fire around every `client.getXxxDetails(...)`. `HookContext.getCtx()` exposes the **merged** context — that's what makes an audit trail useful instead of a "got here" log line.

For an end-to-end summary of how the three layers fit together once the level is solved, see [solutions/intermediate.md → Why This Layout Works](./solutions/intermediate.md#-why-this-layout-works).

## 🧠 What You'll Learn

- How OpenFeature's **transaction-context propagation** works in a thread-per-request server, and why a `ThreadLocalTransactionContextPropagator` is the right primitive for Servlet-based apps
- The difference between **request-scoped context** (the subject's species) and **global evaluation context** (the trial's country) — and when each is the right tool
- How **hooks** let you attach cross-cutting behaviour — audit logging today, OpenTelemetry tracing tomorrow — without modifying every flag evaluation call site

## 🧰 Toolbox

Your Codespace comes pre-configured with the following tools:

- [Java 21](https://adoptium.net/) toolchain (Temurin)
- The Spring Boot Maven Wrapper (`./mvnw`) — no global Maven install required
- `curl` and `jq` for poking at the lab
- `tail -f` for watching the application log live

The flagd sibling that the Beginner level introduced is still running here — the broken-state `OpenFeatureConfig` already targets it via `Resolver.RPC` (`flagd:8013` from the workspace, `localhost:8013` from your host).

## ⏰ Deadline

> 🚧 **Coming Soon** — this level is in the planned bucket. Final deadline will be announced when the adventure goes live.

## 💬 Join the discussion

> 🚧 **Coming Soon** — community thread will be linked here at launch.

## ✅ How to Play

### 1. Start Your Challenge

> 📖 **First time?** Check out the [Getting Started Guide](../../start-a-challenge) for detailed instructions on forking, starting a Codespace, and waiting for infrastructure setup.

Quick start:

- Fork the repo
- Create a Codespace
- Select "Adventure 00 | 🟡 Intermediate (Outcome by cohort)"
- Wait ~2-3 minutes for the Java toolchain to install (`Cmd/Ctrl + Shift + P` → `View Creation Log` to view progress)

When the post-create finishes you'll have Java 21, the Maven wrapper, and the broken-state lab ready in `adventures/planned/00-blind-by-design/intermediate/`.

### 2. Inspect the Starting Point

The lab already has the OpenFeature SDK and the flagd contrib provider on the classpath, and the `FlagdProvider` is wired in `Resolver.RPC` mode against the flagd sibling. The `flags.json` shipping with this level is the targeting-rich version — all three branches (open `intermediate/flags.json` and you'll see this verbatim):

```json
"targeting": {
  "if": [
    { "===": [{"var": "species"}, "zyklop"] },                  "enhanced",
    { "in":  [{"var": "dose"},    ["underdose", "overdose"]] }, "clouded",
    { "===": [{"var": "country"}, "de"] },                      "sharp"
  ]
}
```

The catch: nothing in the application populates `species`, `country`, or `dose` yet. Every request lands with an empty evaluation context, so none of the branches fire and every subject walks out with `"blurry"` (the default variant) — even when they show up as a zyklop.

Boot the lab as-is to confirm the symptom — either click **Run** on `Laboratory` in the Spring Boot Dashboard panel (or press **F5** with `Laboratory.java` open), or, from the terminal:

```bash
cd adventures/planned/00-blind-by-design/intermediate
./mvnw spring-boot:run
```

In another terminal:

```bash
curl 'http://localhost:8080/?species=zyklop'
# => {"value":"blurry", ...}    ← wrong cohort, no targeting fired
```

Stop the app (`Ctrl+C`) and start fixing.

### 3. Implement the Objective

You need three pieces.

#### 3a. A `SpeciesInterceptor`

Create a Spring `HandlerInterceptor` that:

- In `preHandle`, reads both `?species=` and `?userId=` from the request, puts `species` on the **transaction context**, and sets `userId` as the **`targetingKey`**. (See [`ImmutableContext` constructors in the OpenFeature Java SDK](https://openfeature.dev/docs/reference/technologies/server/java/) — there's a constructor that takes the targetingKey explicitly.)
- In `afterCompletion`, clears the transaction context. Servlet threads are pooled — if you don't clear, the previous request's species or targetingKey leaks into whichever request lands on the thread next.
- In a static initialiser, registers a `ThreadLocalTransactionContextPropagator` once on the OpenFeature API. Without it the SDK has no way to carry per-request context across the call into the controller, and the transaction context silently stays empty.

> ℹ️ The Intermediate `verify.sh` doesn't exercise the `?userId=` branch (no Intermediate flag uses `targetingKey`). If you skip that branch, Intermediate still passes — but the Expert level's variant-distribution panel will collapse to a single bucket. The wiring is forward-looking on purpose.

#### 3b. Wire the interceptor + global context + hook in `OpenFeatureConfig`

Update `OpenFeatureConfig` to:

- Register your `SpeciesInterceptor` with Spring (`WebMvcConfigurer.addInterceptors`).
- Read `COUNTRY` from the environment and set it as the **global** evaluation context — merged into every flag evaluation regardless of request.
- Register your `AuditHook` (you'll write that next) globally on the OpenFeature API.

#### 3c. An `AuditHook`

Create a `Hook` that, on `after(...)`, reads the merged evaluation context off `HookContext.getCtx()` and writes an `[AUDIT]` log line naming the flag, the resolved variant, the reason, and the attributes that drove the outcome. Two design decisions worth thinking about:

- When the resolved variant is `clouded`, log at **`WARN`** so the safety officer can grep for it; otherwise `INFO`. Also implement `error(...)` — failed evaluations shouldn't disappear silently.
- Use a **fixed allowlist** of attribute keys, not the whole context. That's what the PII callout below is about.

> ⚠️ **Audit-log PII note.** Use a **fixed allowlist** (`List.of("species", "country", "dose")`) — never iterate the whole eval context.
>
> You just wired `?userId=` as the **targetingKey** in step 3a. That's the canonical example of something that lives on the eval context but does **not** belong in an audit log: it's typically a stable user id, often joins to email and account data, and audit logs are retained longer than app logs and shipped off-host to SIEMs (where redacting after the fact is hard). The allowlist is what keeps the targetingKey out of `[AUDIT]` lines even though `HookContext.getCtx()` can see it. Same discipline the Expert OTel hook will need; see [OpenTelemetry's security guidance](https://opentelemetry.io/docs/security/).

The order matters less than you'd think — Spring will pick up `OpenFeatureConfig` as a `@Configuration` class on boot, the `@PostConstruct` will run once, and from then on every evaluation the `Trial` performs will see both contexts and trigger your hook.

### 4. Run the Lab

```bash
cd adventures/planned/00-blind-by-design/intermediate
./run-germany.sh   # COUNTRY=de — exercises the country-targeting branch
```

`./run-austria.sh` (`COUNTRY=at`) ships alongside it for the no-targeting case. Three named launch configs in `.vscode/launch.json` (Germany / Austria / No country) give you one-click cohort switching from the **Run and Debug** view.

### 5. Verify Each Cohort by Hand

In another terminal — exercise all three context layers and the precedence between them:

```bash
# Transaction context — species wins, regardless of country / dose
curl -s 'http://localhost:8080/?species=zyklop' | jq .value
# => "enhanced"

# Global context — country=de from the env. Pin ?dose=standard so the
# random dose pick can't trip the improper-dose branch.
curl -s 'http://localhost:8080/?dose=standard' | jq .value
# => "sharp"     (when running ./run-germany.sh — COUNTRY=de)
# => "blurry"    (when running ./run-austria.sh — COUNTRY=at: no targeting branch fires, default applies)

# Invocation context — improper dose for a non-zyklop subject
curl -s 'http://localhost:8080/?dose=underdose' | jq .value
# => "clouded"

# Precedence — species-zyklop is evaluated before improper-dose in flags.json
curl -s 'http://localhost:8080/?species=zyklop&dose=underdose' | jq .value
# => "enhanced"
```

Tail the log to see the audit trail:

```bash
grep '\[AUDIT\]' app.log | head
```

You should see one `[AUDIT] flag=vision_state variant=… reason=… species=… country=… dose=…` line per `curl` call. `clouded` outcomes log at `WARN` with the "improper dosing or off-protocol cohort, follow-up required" suffix.

### 6. Run the Verification Script

```bash
adventures/planned/00-blind-by-design/intermediate/verify.sh
```

The script checks that the app is reachable, the zyklop and German cohorts return the right values, and the log file contains audit-hook lines.

> 🧪 **Spoiler ahead?** A full walkthrough lives in [solutions/intermediate.md](./solutions/intermediate.md). Try it on your own first — the cohorts will thank you.
