# Agent Guidelines

This guide is for AI agents working on the Open Ecosystem Challenges repository.
For structural scaffolding, use `scripts/new-adventure.sh`. This document covers
everything that is easy to miss.

## Ground Rules

- **Never assume — always ask.** If intent is unclear, ask before implementing.
- **Propose before acting.** For anything structural (new files, renames, moving things),
  outline the approach and get confirmation first.
- **Be critical.** If something seems inconsistent or wrong, flag it. Don't silently comply.
- **Read the docs in place.** Before working on an adventure, read the contributing guide
  and relevant documentation in the repo. Don't rely on assumptions or memory — read the
  actual files.

---

## Creating a New Adventure

Never create adventure files manually. The correct flow is:

1. An approved idea file must exist in `ideas/` before any implementation begins.
   Never start building an adventure without one.
2. Run `scripts/new-adventure.sh` to scaffold the adventure structure from the idea file.
   This ensures consistent structure across all adventures.

---

## Building Challenges

> Read [CONTRIBUTING.md](./CONTRIBUTING.md) first — it covers the full step-by-step process.
> The sections below capture things that are easy to miss on top of that guide.


### Story structure

The adventure overview should follow this arc: a world (how things worked before),
a fall (what broke), a mystery (why it matters / what's hidden), and a role for the
player. Stay in the story world — don't name tools or technologies in the overview.
Technical terms can bleed in at the level story layer, but the overview should read
as narrative, not a feature list. Use Lex Imperfecta as the reference example.

### Theme consistency

Every technical element should have a thematic counterpart — label keys, error messages,
pod names, policy descriptions. Thematic flavor enhances the experience but must never
obscure what the player needs to understand technically.

When in doubt: combine both. A Roman-themed error message can still explain *why* the
policy exists.

### Intentional bugs

- Always work backwards from the solution. Implement the fully working state first,
  verify it, then introduce bugs from there. Never design the buggy state first.
- One concept per bug — keep bugs focused and isolated.
- Keep challenge artifacts minimal. Only include what is directly relevant to the concept
  being tested — anything extra distracts beginners. For example, a test workload should
  not include security context fields or resource limits that aren't part of the challenge.

### verify.sh

- Always define an `OBJECTIVE` variable at the top that matches the wording in the docs exactly.
- Use inline YAML heredocs for test manifests — never reference files from `manifests/workloads/`
  since those are player-editable. The verify script must be self-contained.
- Extend `lib/scripts/` with reusable helper functions rather than writing logic inline
  in verify.sh. Keep verify.sh a clean list of check calls.
- Hints must be **directional, not prescriptive**:
  - Bad: `"is the validationFailureAction set to Enforce?"`
  - Good: `"what happens when a violation is detected?"`
  - The hint should point players to *where* to look, not *what* to change.

### Devcontainer / post-start

- `post-create.sh`: install tools, set up the cluster, install dependencies.
- `post-start.sh`: deploy the initial challenge state (policies + workloads). The goal is
  that players open their Codespace and the problem is immediately visible — not a blank
  slate. The broken state should be the first thing they see.

### Ports (NodePorts)

NodePorts are a single, cluster-wide namespace. `lib/kubernetes/config.yaml` (shared by
every adventure) maps each one to the host, so a port number must mean the same tool
everywhere. Treat that file as the authoritative port registry.

- **One tool, one port, globally.** Never reuse a NodePort for a different tool. If two
  challenges each grabbed, say, 30110 for different services, a future challenge that needs
  both tools at once could not run. Gitea is always 30112, Falcosidekick always 30111, and
  so on.
- **Reuse across levels is fine for the same tool** (the Dead Reckoning beginner and
  intermediate both serve Gitea on 30112). Reuse across *different* tools is not.
- **Adding a new tool:** claim the next free `hostPort`/`containerPort` in
  `lib/kubernetes/config.yaml`, label it with the tool's name in a comment, and forward it
  in the level's `devcontainer.json`. If the tool is already listed there, reuse its
  existing port instead of allocating a new one.

### Makefile

Keep it minimal. For a typical challenge level:
- `make apply` — reset everything (delete known pods, re-apply policies, re-apply workloads)
- `make verify` — run verify.sh

Don't add targets that duplicate verify.sh logic or that give players shortcuts that
bypass learning.

### Shared scripts

`lib/scripts/loader.sh` sources all shared helper functions automatically. Always source
it at the top of verify.sh. Before writing any verification logic, check whether a helper
already exists in `lib/scripts/` — prefer extending the shared library over writing
inline logic.

### Pre-release checklist

When explicitly asked to review an adventure for release readiness, check:

- Deadline is filled in (not empty)
- Community thread link is not a `TODO`
- `Status: Coming Soon` is updated to reflect actual state
- Adventure has a real number assigned (not `00`, which is the placeholder for planned adventures)
- No `<!-- TODO -->` comments remain in any docs
- verify.sh hints have been reviewed — none give away the exact fix
- `OBJECTIVE` in verify.sh matches the `## 🎯 Objective` section in the docs

Only make changes to these when explicitly prompted to do so.

### Docs

- The `## 🎯 Objective` section in the docs and the `OBJECTIVE` variable in verify.sh
  must match.
- `## 🧠 What You'll Learn` bullet points should link to the relevant docs pages.
- Hints in `verify.sh` must not appear in the docs — the docs describe *what* to achieve,
  not *how* to fix it.
- The `## 🏗️ Architecture` section should explicitly tell players which files to edit
  and which to leave alone.
