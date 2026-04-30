#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHALLENGE_DIR="$REPO_ROOT/adventures/planned/00-blind-by-design/expert"

cat <<EOF

✨ Adventure 00 — Level 3 (🔴 Expert): Phase 3 — read the chart

📂 Challenge directory:
   $CHALLENGE_DIR

🧪 Sibling services already running (managed by devcontainer compose):
   - flagd   → flagd:8013 (gRPC eval) / flagd:8016 (OFREP HTTP)
               Management/metrics on :8014, sync stream on :8015.
   - lgtm    → lgtm:4317 (OTLP) / Grafana on http://localhost:3000 (admin / admin)
   - loadgen → idles until loadgen_active flag flips to "on"

   All ports are forwarded to localhost on the host, so curl, verify.sh,
   and the browser can keep using localhost:NNNN.

▶  Run the lab — one launch config in .vscode/launch.json:
     🧪  Run the Phase 3 Lab
   Open the Run and Debug view (Ctrl/Cmd + Shift + D) and hit ▶.

   Or from the terminal:
     ./mvnw spring-boot:run

✅ Run the verification when you're ready:
     ./verify.sh
   or use the 🧪 Verify Solution task: Tasks → Run Test Task.

EOF

# Track that the environment is ready
# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "blind-by-design" "expert"
track_codespace_initialized

# Open the relevant files in the connected editor. customizations.codespaces.openFiles
# is unreliable for dockerComposeFile-based devcontainers (the orchestrator merges
# devcontainer.json and the field is sometimes dropped). `code` is the same CLI the
# editor uses internally and works against either the web or desktop client.
if command -v code >/dev/null 2>&1; then
  code "$REPO_ROOT/adventures/planned/00-blind-by-design/docs/expert.md" \
       "$CHALLENGE_DIR/src/main/java/dev/openfeature/demo/java/demo/OpenTelemetryConfig.java" \
       "$CHALLENGE_DIR/src/main/java/dev/openfeature/demo/java/demo/OpenFeatureConfig.java" \
       "$CHALLENGE_DIR/flags.json" \
       2>/dev/null || true
fi
