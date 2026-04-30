#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHALLENGE_DIR="$REPO_ROOT/adventures/planned/00-blind-by-design/beginner"

cat <<EOF

✨ Adventure 00 — Level 1 (🟢 Beginner): Stand up the lab

📂 Challenge directory:
   $CHALLENGE_DIR

🧬 A flagd sidecar is already running next to your workspace
   - gRPC eval  :8013   (this is what your FlagdProvider will talk to)
   - management :8014   (Prometheus metrics + /healthz, /readyz)
   - sync       :8015   (used in the Intermediate IN_PROCESS sidebar)
   - OFREP      :8016   (HTTP eval API, handy for poking flagd directly)
   FLAGD_HOST=flagd is exported into this shell, so a default
   Resolver.RPC config picks the sidecar up automatically.

▶  Run the lab — one launch config in .vscode/launch.json:
     🧪  Run the Lab
   Open the Run and Debug view (Ctrl/Cmd + Shift + D) and hit ▶.

   Or from the terminal:
     ./mvnw spring-boot:run

👉 In another terminal, hit it:
     curl -s http://localhost:8080/ | jq

✅ Run the verification when you're ready:
     ./verify.sh
   or use the 🧪 Verify Solution task: Tasks → Run Test Task.

EOF

# Track that the environment is ready.
# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
track_codespace_initialized

# Open the relevant files in the connected editor. customizations.codespaces.openFiles
# is unreliable for dockerComposeFile-based devcontainers (the orchestrator merges
# devcontainer.json and the field is sometimes dropped). `code` is the same CLI the
# editor uses internally and works against either the web or desktop client.
if command -v code >/dev/null 2>&1; then
  code "$REPO_ROOT/adventures/planned/00-blind-by-design/docs/beginner.md" \
       "$CHALLENGE_DIR/src/main/java/dev/openfeature/demo/java/demo/Trial.java" \
       2>/dev/null || true
fi
