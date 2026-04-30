# 🟢 Beginner: Stand up the lab

Wire the OpenFeature Java SDK and the flagd contrib provider into a Spring Boot service so flag evaluations are resolved by a flagd sidecar against a `flags.json` file. Author your first flag, then prove that editing `flags.json` flips the response on the **next** request — no app restart, no flagd restart, no redeploy.

The Spring Boot service is already running on `:8080`; a flagd container is already running on `:8013`; `flags.json` is an empty skeleton (`{"flags": {}}`). The SDK is **not** wired in yet — that's your job.

## 🧪 The story (optional)

The lab is on its first shift and it isn't reading the chart. Every subject who walks through the door gets the same hard-coded reading on their record — no matter what the lab director just signed off on. The label coming out of the lab is a literal string baked into the controller, not a reading pulled from the chart.

Your mission: replace that hard-coded label with an OpenFeature client, point that client at the **flagd sidecar** that already runs next to your Codespace, and let `flags.json` drive what gets recorded as the subject's `vision_state`. While you're at it, prove the lab can change what it records **without restarting anything** — edit `flags.json`, save, and the next subject through the door has the new reading on their chart.

## 🏗️ Architecture

This level runs as two containers side-by-side in your Codespace — the Spring Boot lab and a flagd sidecar.

- **The lab** — a Spring Boot 4 service on `http://localhost:8080/` with one endpoint, `GET /`. Today it returns a hard-coded `"untreated"` literal from `Trial`.
- **The chart** — a `flags.json` file in the level folder, mounted **read-only** into the flagd sidecar. The participant edits it through the IDE; flagd's file watcher picks up the change.
- **The flagd sidecar** — `ghcr.io/open-feature/flagd:latest`, started by the devcontainer compose stack. It serves flag evaluations over **gRPC on `:8013`**, watches `flags.json` on disk, and reloads when it changes.
- **The chart system** — the OpenFeature Java SDK plus the **flagd contrib provider** in `Resolver.RPC` mode. The provider reads `FLAGD_HOST=flagd` / `FLAGD_PORT=8013` from the environment (the compose file pre-sets them), so there is no host or port to hard-code.

## 🎯 Objective

By the end of this level, you should:

- Have `curl http://localhost:8080/` return a `vision_state` reading **resolved from `flags.json`** (not the hard-coded `"untreated"` fallback)
- Confirm the response payload includes the **OpenFeature evaluation details** — flag key, variant, reason, value
- Edit `flags.json` to change the `defaultVariant`, save, and have the **next** request return the new variant **without restarting the app**

## 🧠 What You'll Learn

- How an OpenFeature client and provider work together — the SDK is provider-agnostic and the flagd provider plugs in via dependency only
- What "remote provider" means in practice — the SDK calls a separate flag service (flagd) over gRPC; the SDK does not parse `flags.json` itself
- What `flags.json` looks like for flagd (`state`, `variants`, `defaultVariant`)
- Why hot-reload of the flag file matters operationally — configuration without redeploy

## 🧰 Toolbox

Your Codespace comes pre-configured with the following tools to help you solve the challenge:

- [`./mvnw`](https://maven.apache.org/wrapper/): The Maven wrapper checked in next to `pom.xml`. Builds and runs the Spring Boot lab.
- [`curl`](https://curl.se/): Hits `http://localhost:8080/` and shows you what reading the lab is recording.
- [`jq`](https://jqlang.org/): Pretty-prints and filters the JSON evaluation details that come back from the SDK.
- A **flagd sidecar** — already running in the devcontainer's compose stack. The flagd sidecar is on `:8013`; the other ports aren't used here.

## ⏰ Deadline

_TBD — to be announced at challenge launch._
> ℹ️ You can still complete the challenge after this date, but points will only be awarded for submissions before the
> deadline.

## 💬 Join the discussion

Share your solutions and questions in the challenge thread on the Open Ecosystem Community.
_Discussion link will be added when this adventure goes live._

## 📝 Solution Walkthrough

> ⚠️ **Spoiler Alert:** The following walkthrough contains the full solution to the challenge. We encourage you to try
> solving it on your own first. Consider coming back here only if you get stuck or want to check your approach.

Need the answer key? Follow the [step-by-step beginner solution walkthrough](./solutions/beginner.md) for the final
`pom.xml` dependencies, `OpenFeatureConfig`, `flags.json`, and `Trial`.

## ✅ How to Play

### 1. Start Your Challenge

- Click the "Fork" button in the top-right corner of the GitHub repo or use
  [this link](https://github.com/dynatrace-oss/open-ecosystem-challenges/fork).
- From your fork, click the green **Code** button → **Codespaces hamburger menu** → **New with options**.
- Select the **Adventure 00 | 🟢 Beginner (Stand up the lab)** configuration.

> ⚠️ **Important:** The challenge will not work if you choose another configuration (or the default).

The Codespace will install a Java 21 toolchain and resolve the Maven dependencies. Once it is ready you'll have a
terminal in
`adventures/planned/00-blind-by-design/beginner/`.

### 2. Access the UIs

Open the **Ports** tab in the bottom panel. You should see:

- **8080 — Lab (Spring Boot).** Click the forwarded address. You should see the current hard-coded response: `untreated`.
- **8013 — flagd gRPC.** This is the flagd sidecar. Nothing to click yet, but knowing it's there is the point: the lab
  is going to talk to this in step 3.

### 3. Implement the Objective

You are turning a hard-coded label into a real protocol-driven reading. Work through the steps in this order — each
step makes the next one possible.

#### a. Add the OpenFeature SDK and the flagd provider to `pom.xml`

The lab needs two dependencies: the OpenFeature Java SDK and the flagd contrib provider. GroupIds, artifactIds, and current versions are in the
[OpenFeature Java SDK docs](https://openfeature.dev/docs/reference/technologies/server/java/) and the
[flagd Java provider readme](https://github.com/open-feature/java-sdk-contrib/tree/main/providers/flagd).

#### b. Configure the OpenFeature provider

Create a Spring `@Configuration` class that, at startup, builds a `FlagdProvider` in **RPC mode** and registers it on the global OpenFeature API. The [flagd Java provider readme](https://github.com/open-feature/java-sdk-contrib/tree/main/providers/flagd) covers `FlagdOptions` / `Resolver.RPC` usage.

You don't need to set host or port — the devcontainer pre-sets `FLAGD_HOST=flagd` and `FLAGD_PORT=8013` in the environment, and the provider reads those automatically.

#### c. Author the `vision_state` flag in `flags.json`

The level ships an empty `flags.json` next to `pom.xml` (`{"flags": {}}`) so the flagd sidecar has a valid file to mount at boot. Open it and add a flag named `vision_state` with **two string variants** (e.g. `blurry` and `clouded`) so you have something to flip in the verification step. The schema (`state`, `variants`, `defaultVariant`) is in the [flagd flag-definitions reference](https://flagd.dev/reference/flag-definitions/).

Save — flagd's file watcher picks the change up within about a second; no restart needed.

#### d. Read the chart from `Trial`

Replace the hard-coded `return "untreated";` with an OpenFeature evaluation of the `vision_state` flag, using `"untreated"` as the fallback. **Return the full evaluation details** (not just the value) so the response carries the flag key, variant, value, and reason — that's what the verifier checks.

The Java SDK's evaluation methods are documented in the [OpenFeature Java SDK reference](https://openfeature.dev/docs/reference/technologies/server/java/).

#### e. Restart the lab, then prove hot-reload

You have two ways to start the lab:

- **Click ▶ in VS Code.** The Spring Boot Dashboard panel (one of the recommended extensions in this devcontainer) lists `Laboratory` with a **Run** button. Or press **F5** with `Laboratory.java` open and pick **Java** as the debugger — Spring's main class is detected automatically; no launch.json needed.
- **From the terminal** in the level folder:

  ```bash
  ./mvnw spring-boot:run
  ```

In another terminal:

```bash
curl -s http://localhost:8080/ | jq
```

You should see `"value": "blurry"` and `"flagKey": "vision_state"`. Now, **without stopping the app or the flagd
sidecar**, edit `flags.json` and change `"defaultVariant": "blurry"` to `"defaultVariant": "clouded"`. Save, then
re-run the `curl`. The value should flip to `"clouded"` — that's flagd's file watcher noticing the change on disk
and serving the new variant on the next gRPC evaluation. Nothing redeployed; nothing restarted.

### 4. Verify Your Solution

Once you think you've solved the challenge, it's time to verify!

#### Run the Smoke Test

Run the provided smoke test script (the lab must still be running on `:8080`):

```bash
adventures/planned/00-blind-by-design/beginner/verify.sh
```

The script will:

1. Confirm `http://localhost:8080/` is reachable.
2. Confirm the response is OpenFeature evaluation details for the `vision_state` flag.
3. Confirm the value is **not** the hard-coded `"untreated"` fallback.
4. Swap `defaultVariant` in `flags.json`, wait for the file watcher, confirm the response changes, then restore the
   original file.

If the test passes, your solution is very likely correct! 🎉

## ✅ Verification

A passing run looks roughly like this:

```text
✅ PASSED: All 4 checks passed

It looks like you successfully completed this level! 🌟
```

```json
{
  "flagKey": "vision_state",
  "value": "blurry",
  "variant": "blurry",
  "reason": "STATIC",
  "errorCode": null,
  "errorMessage": null,
  "flagMetadata": {}
}
```

If you see `"value": "blurry"` (or `"clouded"`) and `"flagKey": "vision_state"`, you're ready for the 🟡 Intermediate level — **Outcome by cohort**.
