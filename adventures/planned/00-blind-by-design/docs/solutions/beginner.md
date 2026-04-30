# 🟢 Beginner — Solution Walkthrough: Stand up the lab

> ⚠️ **Spoiler Alert:** This page walks through the full solution. If you want to figure it out yourself, head back to
> the [Beginner challenge](../beginner.md) and only return when you're stuck.

You are taking a Spring Boot service that returns a hard-coded label and turning it into a lab that reads its
prescription from `flags.json` through OpenFeature. There are four moving parts to get right: the dependencies, the
provider configuration, the flag file, and the controller. Below is the answer key for each.

## 1. Add the OpenFeature SDK and the flagd provider

The `pom.xml` you start with has only the Spring starters. Add the OpenFeature SDK and the flagd contrib provider —
these are the two libraries the lab needs to evaluate flags.

Open `pom.xml` and add the following inside `<dependencies>`:

```xml
<dependency>
    <groupId>dev.openfeature</groupId>
    <artifactId>sdk</artifactId>
    <version>1.14.2</version>
</dependency>
<dependency>
    <groupId>dev.openfeature.contrib.providers</groupId>
    <artifactId>flagd</artifactId>
    <version>0.11.8</version>
</dependency>
```

The first one is the vendor-neutral OpenFeature client — the API you call from your code. The second one is the
**provider**: the piece that knows how to talk to flagd. The SDK is provider-agnostic on purpose; you swap the
provider, your call sites stay the same.

## 2. Point the FlagdProvider at the flagd sibling

The provider has to be registered with OpenFeature before any evaluation can happen. Create a new file
`src/main/java/dev/openfeature/demo/java/demo/OpenFeatureConfig.java`:

```java
package dev.openfeature.demo.java.demo;

import dev.openfeature.contrib.providers.flagd.Config;
import dev.openfeature.contrib.providers.flagd.FlagdOptions;
import dev.openfeature.contrib.providers.flagd.FlagdProvider;
import dev.openfeature.sdk.OpenFeatureAPI;
import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenFeatureConfig {

    @PostConstruct
    public void initProvider() {
        OpenFeatureAPI api = OpenFeatureAPI.getInstance();
        FlagdOptions flagdOptions = FlagdOptions.builder()
                .resolverType(Config.Resolver.RPC)
                .build();

        api.setProviderAndWait(new FlagdProvider(flagdOptions));
    }
}
```

A few things worth noting:

- `Resolver.RPC` tells the provider to talk to a flagd process over gRPC. The flagd sibling is already running in your
  Codespace (look in the **Ports** tab for the `flagd gRPC` row on `:8013`).
- We do **not** hard-code a host or port. The Java flagd provider reads `FLAGD_HOST` / `FLAGD_PORT` from the
  environment when no explicit value is set. The devcontainer's compose file pre-sets `FLAGD_HOST=flagd` so the lab
  resolves the sibling by service name; running outside the devcontainer falls back to `localhost:8013` via the
  published port.
- `setProviderAndWait` blocks until the provider has finished initializing, which means the first request the
  controller serves is already wired up.

> 💡 The flagd contrib provider supports three resolver modes:
>
> - `RPC` — one gRPC round-trip per evaluation. Simplest wire model, easiest to reason about.
> - `IN_PROCESS` — the SDK opens a gRPC sync stream and the flag definitions stream **into** the JVM. Evaluations
>   then happen locally, with no per-call network hop. This is the most common shape in real production deployments
>   (flagd as a sidecar) — we lead with `RPC` here only because the wire model is more explicit and easier to
>   debug at level 1. Intermediate has a sidebar on flipping to `IN_PROCESS` against the same flagd sibling.
> - `FILE` — read flags.json from local disk, no flagd at all. Useful for tests and local development without a
>   sidecar.

## 3. Author the flag file

The broken state already ships a `flags.json` next to `pom.xml` — it just has an empty `flags` object so the flagd
sibling has a valid file to mount at boot. Open it and add the `vision_state` flag definition:

```json
{
  "flags": {
    "vision_state": {
      "state": "ENABLED",
      "variants": {
        "blurry": "blurry",
        "clouded": "clouded"
      },
      "defaultVariant": "blurry"
    }
  }
}
```

Three required fields per flag in flagd:

- **`state`** — `"ENABLED"` (or `"DISABLED"` to force the SDK fallback).
- **`variants`** — a map from variant name to value. Two variants here give you something to flip in the verification
  step.
- **`defaultVariant`** — which variant gets returned when no targeting rules match. There are no rules at this level,
  so this is the variant every request gets.

Save. flagd is watching this file (the devcontainer mounts it read-only into the flagd sibling and tells it to
`start --uri file:.../flags.json`), so the next evaluation already sees the new flag — no flagd restart, no app
restart.

## 4. Read the chart from the controller

Update `src/main/java/dev/openfeature/demo/java/demo/Trial.java` so it asks OpenFeature for the reading
instead of returning a literal:

```java
package dev.openfeature.demo.java.demo;

import dev.openfeature.sdk.Client;
import dev.openfeature.sdk.FlagEvaluationDetails;
import dev.openfeature.sdk.OpenFeatureAPI;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class Trial {

    @GetMapping("/")
    public FlagEvaluationDetails<String> observeSubject() {
        Client client = OpenFeatureAPI.getInstance().getClient();
        return client.getStringDetails("vision_state", "untreated");
    }
}
```

Two intentional choices here:

- `"untreated"` is the **fallback** value passed to `getStringDetails`. The SDK only returns it if no provider is
  registered, the flag is missing, or the flag is disabled. Once your `OpenFeatureConfig` and `flags.json` are in
  place, you should never see this value again — and the smoke test asserts exactly that.
- The handler returns `FlagEvaluationDetails<String>` directly, not just the value. Spring will serialize it to JSON
  and the response will carry `flagKey`, `value`, `variant`, `reason`, and any error fields — useful for debugging,
  required by the smoke test.

## 5. Run it and verify

Restart the lab:

```bash
./mvnw spring-boot:run
```

In another terminal:

```bash
curl -s http://localhost:8080/ | jq
```

You should see `"value": "blurry"` and `"flagKey": "vision_state"`. Edit `flags.json`, change
`"defaultVariant": "blurry"` to `"defaultVariant": "clouded"`, save, and `curl` again — the value flips to
`"clouded"` without restarting the app. That's the **flagd container** noticing the file changed on its read-only
mount and serving the new variant on the next gRPC evaluation. Neither the lab nor flagd had to restart; nothing
was redeployed.

Run the smoke test from the repo root:

```bash
adventures/planned/00-blind-by-design/beginner/verify.sh
```

When all four checks pass, the lab is reading the chart and you're done with the 🟢 Beginner level.
