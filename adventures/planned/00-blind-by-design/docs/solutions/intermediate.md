# 🟡 Intermediate Solution Walkthrough: Outcome by cohort

This walkthrough shows the target shape of the lab after the level is solved. We'll build it the way a clinical engineer would — read the objective, then drop in each piece in the order the OpenFeature SDK expects it.

> ⚠️ **Spoiler Alert:** The full solution is below. Try the level on your own first.

## 📋 Step 1: Recap the Objective

You need four pieces of code wired together:

1. A `SpeciesInterceptor` that captures the `?species=` query parameter into the OpenFeature **transaction context** for the duration of the request.
2. An `AuditHook` that records every flag evaluation with the cohort attributes that drove it.
3. An updated `OpenFeatureConfig` that registers the interceptor, reads `COUNTRY` from the environment and sets it on the **global** evaluation context, and registers the audit hook.
4. An updated `Trial` controller that accepts `?dose=` and passes a `dose` attribute as **invocation context** at the call site of `client.getStringDetails(...)`.

The flag definition in `flags.json` is already targeting-rich — `species == zyklop`, the improper-`dose` branch, and the `country == de` branch are all in place.

## 🧩 Step 2: The `SpeciesInterceptor`

Create `src/main/java/dev/openfeature/demo/java/demo/SpeciesInterceptor.java`:

```java
package dev.openfeature.demo.java.demo;

import dev.openfeature.sdk.ImmutableContext;
import dev.openfeature.sdk.OpenFeatureAPI;
import dev.openfeature.sdk.ThreadLocalTransactionContextPropagator;
import dev.openfeature.sdk.Value;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.HashMap;

public class SpeciesInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        String species = request.getParameter("species");
        String userId = request.getParameter("userId");
        HashMap<String, Value> attributes = new HashMap<>();
        if (species != null) {
            attributes.put("species", new Value(species));
        }
        ImmutableContext evaluationContext = userId != null
                ? new ImmutableContext(userId, attributes)
                : new ImmutableContext(attributes);
        OpenFeatureAPI.getInstance().setTransactionContext(evaluationContext);
        return HandlerInterceptor.super.preHandle(request, response, handler);
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) throws Exception {
        OpenFeatureAPI.getInstance().setTransactionContext(new ImmutableContext());
        HandlerInterceptor.super.afterCompletion(request, response, handler, ex);
    }

    static {
        OpenFeatureAPI.getInstance().setTransactionContextPropagator(new ThreadLocalTransactionContextPropagator());
    }
}
```

A few details worth calling out:

- The static initialiser registers a `ThreadLocalTransactionContextPropagator` on the API. Without it the SDK has no way to carry per-request context across the call into the controller — the transaction context would silently be empty.
- `afterCompletion` clears the context. Servlet container threads are pooled, so leaving the previous request's species or `targetingKey` on the thread would leak it into the *next* request unlucky enough to land on the same thread.
- The `ImmutableContext(targetingKey, attributes)` constructor is the explicit way to set the targetingKey alongside other attributes; the `ImmutableContext(attributes)` overload leaves it unset. We branch on whether `userId` is present so a missing `?userId=` doesn't poison the context with a `null` targetingKey.
- No Intermediate flag uses the targetingKey yet — Intermediate's `vision_state` targets attributes, not a fractional bucket. The wiring is forward-looking: Expert's `vision_amplifier_v2` is a fractional rollout that buckets on `targetingKey`, so this interceptor is the same one Expert ships, byte for byte.

## 🧩 Step 3: The `AuditHook`

Create `src/main/java/dev/openfeature/demo/java/demo/AuditHook.java`. The lab director wants an audit trail: every evaluation logged with the cohort attributes that drove the outcome, and a warning when a subject's reading comes back `clouded` (improper dosing, the safety officer needs to follow up):

```java
package dev.openfeature.demo.java.demo;

import dev.openfeature.sdk.EvaluationContext;
import dev.openfeature.sdk.FlagEvaluationDetails;
import dev.openfeature.sdk.Hook;
import dev.openfeature.sdk.HookContext;
import dev.openfeature.sdk.Value;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Map;

public class AuditHook implements Hook {
    private static final Logger LOG = LoggerFactory.getLogger(AuditHook.class);

    /** Allowlist of context attributes that are safe to drop into the audit log. */
    private static final List<String> AUDITED = List.of("species", "country", "dose");

    @Override
    public void after(HookContext ctx, FlagEvaluationDetails details, Map hints) {
        StringBuilder ctxLine = new StringBuilder();
        EvaluationContext ec = ctx.getCtx();
        for (String key : AUDITED) {
            Value v = ec != null ? ec.getValue(key) : null;
            ctxLine.append(' ').append(key).append('=').append(v != null ? v.asString() : "(absent)");
        }
        String message = String.format("[AUDIT] flag=%s variant=%s reason=%s%s",
                ctx.getFlagKey(), details.getVariant(), details.getReason(), ctxLine);

        if ("clouded".equals(details.getVariant())) {
            LOG.warn("{} -- improper dosing or off-protocol cohort, follow-up required", message);
        } else {
            LOG.info("{}", message);
        }
    }

    @Override
    public void error(HookContext ctx, Exception err, Map hints) {
        LOG.warn("[AUDIT] flag evaluation error flag={} err={}", ctx.getFlagKey(), err.toString());
    }
}
```

Two things worth pinning down:

- The hook reads from `HookContext.getCtx()` — the **merged** context the SDK was about to evaluate against. So whether the attribute came from the global eval context (`country`), the transaction context (`species` via `SpeciesInterceptor`), or the invocation context (`dose` from the controller call site), the audit line sees it.
- `AUDITED` is a **fixed allowlist** on purpose. Audit logs are usually retained longer than application logs and are often shipped to a SIEM. Don't iterate over the whole context — `targetingKey` and other PII routinely sit there in real apps. Same discipline that the Expert level's OTel hook needs, just with weaker retention. The OpenTelemetry [security & privacy guidance](https://opentelemetry.io/docs/security/) says it best.

What you trade up to in the Expert level: the same `Hook` shape but the output goes onto OpenTelemetry spans instead of a log file, so the dashboard can correlate variants with context attrs in real time.

## 🧩 Step 4: Update `OpenFeatureConfig`

Replace `src/main/java/dev/openfeature/demo/java/demo/OpenFeatureConfig.java` with:

```java
package dev.openfeature.demo.java.demo;

import dev.openfeature.contrib.providers.flagd.Config;
import dev.openfeature.contrib.providers.flagd.FlagdOptions;
import dev.openfeature.contrib.providers.flagd.FlagdProvider;
import dev.openfeature.sdk.ImmutableContext;
import dev.openfeature.sdk.OpenFeatureAPI;
import dev.openfeature.sdk.Value;
import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.HashMap;
import java.util.Optional;

@Configuration
public class OpenFeatureConfig implements WebMvcConfigurer {

    @PostConstruct
    public void initProvider() {
        OpenFeatureAPI api = OpenFeatureAPI.getInstance();
        FlagdOptions flagdOptions = FlagdOptions.builder()
                .resolverType(Config.Resolver.RPC)
                .build();

        api.setProviderAndWait(new FlagdProvider(flagdOptions));

        // Read the trial's country of registration from the environment.
        // Empty string when unset — flagd's `===` operator simply won't match,
        // and the default variant wins.
        String country = Optional.ofNullable(System.getenv("COUNTRY")).orElse("");
        HashMap<String, Value> attributes = new HashMap<>();
        attributes.put("country", new Value(country));
        ImmutableContext evaluationContext = new ImmutableContext(attributes);
        api.setEvaluationContext(evaluationContext);

        api.addHooks(new AuditHook());
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new SpeciesInterceptor());
    }
}
```

What changed compared to the broken-state file:

- The class now `implements WebMvcConfigurer` and overrides `addInterceptors` to register `SpeciesInterceptor`. Spring picks this up automatically because the class is a `@Configuration`.
- The stale `offlineFlagSourcePath("./flags.json")` line on `FlagdOptions` is gone. With `Resolver.RPC` the SDK ignores it anyway — the flagd sibling reads `flags.json` itself; the SDK only talks to flagd over gRPC. Drop it for clarity.
- After `setProviderAndWait`, we read `System.getenv("COUNTRY")`, build a one-attribute `ImmutableContext` with `country` set to that value, and call `api.setEvaluationContext(...)`. This context merges into every evaluation regardless of request.
- We call `api.addHooks(new AuditHook())` to register the audit hook on every evaluation.

## 🧩 Step 5: Update `Trial` to pass `dose` as invocation context

This is the third (and last) of the three eval-context layers — and it's the one that has to live at the **call site**, not in a Spring filter or a `@PostConstruct`. The dose is observational: most subjects absorb the standard dose, but a measurable fraction end up underdosed or overdosed (missed doses, fast metabolisers, the usual reasons), and that's known only at the moment the lab takes the reading. Replace `src/main/java/dev/openfeature/demo/java/demo/Trial.java` with:

```java
package dev.openfeature.demo.java.demo;

import dev.openfeature.sdk.Client;
import dev.openfeature.sdk.FlagEvaluationDetails;
import dev.openfeature.sdk.ImmutableContext;
import dev.openfeature.sdk.OpenFeatureAPI;
import dev.openfeature.sdk.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.concurrent.ThreadLocalRandom;

@RestController
public class Trial {

    @GetMapping("/")
    public FlagEvaluationDetails<String> observeSubject(@RequestParam(required = false) String dose) {
        Client client = OpenFeatureAPI.getInstance().getClient();

        // The dose this subject actually absorbed. Caller can pin it via ?dose=
        // (handy for testing); otherwise we sample one from the typical
        // adherence distribution we see in this lab.
        String resolvedDose = (dose != null) ? dose : pickDose();
        HashMap<String, Value> invocationCtx = new HashMap<>();
        invocationCtx.put("dose", new Value(resolvedDose));

        return client.getStringDetails(
                "vision_state",
                "untreated",
                new ImmutableContext(invocationCtx));
    }

    private static String pickDose() {
        double r = ThreadLocalRandom.current().nextDouble();
        if (r < 0.60) return "standard";
        if (r < 0.90) return "underdose";
        return "overdose";
    }
}
```

Three things worth pinning down:

- The `dose` attribute is **observational, not prescriptive**. The lab's protocol calls for a `"standard"` dose every time; what varies per subject is what their body actually ended up with. The targeting branch in `flags.json` reads "if the dose came back underdose or overdose for a non-zyklop, the reading is `clouded`."
- `getStringDetails(...)` takes the invocation `EvaluationContext` as the **third argument**. The SDK merges it on top of the global context (`country`) and the transaction context (`species` from `SpeciesInterceptor`); on conflict, invocation wins. None of those layers conflict in this level — they each carry a different attribute name.
- Returning `FlagEvaluationDetails<String>` (rather than just `details.getValue()`) keeps the response body verbose: flag key, value, variant, reason. The verifier and your own debugging both lean on those fields.

## ✅ Step 6: Verify

Boot the lab. The level ships two convenience scripts that pre-set `COUNTRY` and pipe to `app.log`:

```bash
./run-germany.sh   # COUNTRY=de
# or
./run-austria.sh   # COUNTRY=at
```

Once you've made the changes above, the four curl cases in [the participant doc's verify-by-hand section](../intermediate.md#5-verify-each-cohort-by-hand) should now resolve as documented — with explicit log lines from your `AuditHook`.

Then check the audit trail:

```bash
grep '\[AUDIT\]' app.log | head
```

You should see one `[AUDIT] flag=vision_state variant=… reason=… species=… country=… dose=…` line per evaluation, and `WARN`-level lines for any `clouded` outcome with the "improper dosing or off-protocol cohort, follow-up required" suffix.

Run the verification script:

```bash
adventures/planned/00-blind-by-design/intermediate/verify.sh
```

If everything passes, every cohort lands on the right reading and the audit log is recording the cohort attributes that drove each one.

## 🧠 Why This Layout Works

- **Transaction context** is the right home for the subject's species because it's per-request and must not survive into the next request. The `ThreadLocalTransactionContextPropagator` is what makes the SDK pick up that per-thread state on every evaluation.
- **Global evaluation context** is the right home for the trial's country because it's a property of the lab instance itself, not the subject. Setting it once at boot is correct, and reading it from `COUNTRY` in the environment lets the same image serve different trials without rebuilding.
- **Invocation context** is the right home for the dose because it's known only at the moment the lab takes the reading — not on the request, not at startup. Passing it at the call site keeps the controller in charge of attributes whose value the controller is the only one to know.
- **Hooks** are registered globally on the API, so every flag evaluation everywhere in the app picks them up — no need to thread the audit logger through every controller.
- **`targetingKey`** lives on the transaction context too, set from `?userId=`. No Intermediate flag uses it, but it's the bucketing key for any fractional rollout further on — and it's the canonical PII identifier that the audit allowlist deliberately keeps out of `[AUDIT]` lines.

That separation is the whole reason OpenFeature ships a vendor-neutral context model. The same code reads cleanly whether the provider is flagd in `Resolver.RPC` mode (this level) or `Resolver.IN_PROCESS` mode against the same flagd sibling — for the resolver-modes overview, see [solutions/beginner.md](./beginner.md).
