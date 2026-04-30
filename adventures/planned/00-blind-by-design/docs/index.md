# 🧪 Adventure 00: Blind by Design

Three levels of OpenFeature with **flagd** as the provider, in a Java + Spring Boot service. Wire the SDK against a flagd sidecar (Beginner), layer evaluation context to target by cohort (Intermediate), then instrument flag evaluations with OpenTelemetry and roll back a misbehaving fractional rollout (Expert) — all without redeploying.

The entire **infrastructure is pre-provisioned in your Codespace** — no local setup required.

## 🪐 The Backstory

OpenFeature is a vendor-neutral standard for feature flags. The reference cloud-native implementation is **flagd** — it serves flag definitions from a JSON file, locally or remotely, and the OpenFeature SDK in your application calls it on every evaluation.

In this adventure, the lab uses OpenFeature exactly the way a real engineering team would: a Spring Boot service holds the SDK client, flagd holds the flag definitions, and the targeting rules in `flags.json` decide what reading every subject ends up with. By the end, you'll have wired the SDK in from scratch, learned to record outcomes by cohort, and rolled back a misbehaving Phase 3 trial without redeploying.

## 🎮 Choose Your Level

Each level is a standalone challenge with its own Codespace that builds on the story while being technically independent — pick your level and start wherever you feel comfortable.

### 🟢 Beginner: Stand up the lab

- **Status:** 🚧 Coming Soon
- **Topics:** OpenFeature Java SDK, flagd as a sidecar (`Resolver.RPC`), Spring Boot

Wire OpenFeature into a Spring Boot service so the lab's `vision_state` reading is resolved by a flagd sidecar against a `flags.json` instead of a hard-coded literal.

[**Start the Beginner Challenge**](./beginner.md){ .md-button .md-button--primary }

### 🟡 Intermediate: Outcome by cohort

- **Status:** 🚧 Coming Soon
- **Topics:** OpenFeature targeting, transaction context, hooks, Spring `HandlerInterceptor`

Add request-scoped context, a global runtime context, an invocation context at the call site, and an audit hook so the lab records the right reading per subject cohort.

[**Start the Intermediate Challenge**](./intermediate.md){ .md-button .md-button--primary }

### 🔴 Expert: Phase 3 — read the chart

- **Status:** 🚧 Coming Soon
- **Topics:** OpenTelemetry traces + metrics, custom hooks, Grafana LGTM, fractional rollout, OpenFeature OTel hooks

Finish wiring OpenTelemetry through to the Grafana LGTM stack, write a `ContextSpanHook` that puts the merged eval context onto Tempo spans, find the misbehaving Phase 3 amplifier in the dashboard, and roll it back without redeploying.

[**Start the Expert Challenge**](./expert.md){ .md-button .md-button--primary }

## 🧪 The story (optional)

A research lab is testing a vision-enhancement serum on volunteers. The **lab** is a Spring Boot service. **OpenFeature** is the chart system. The protocol the lab is following is fixed; what differs per subject is the **`vision_state`** the lab records — `blurry`, `sharp`, `enhanced`, or `clouded` — because subjects don't all arrive with the same biology, the same dose adherence, or the same trial-jurisdiction baseline.

The flagship Phase 3 trial — a new vision-amplifier algorithm — has started showing trouble: subjects stabilise slower, and roughly one in ten emerge **blind**. The dashboard that should be tracking all of this is dark, because the lab forgot to wire the metric exporter. Your mission across three levels: **stand up the lab**, **read the chart by cohort**, then **turn on the lights and roll back the trial** before more subjects lose their sight.
