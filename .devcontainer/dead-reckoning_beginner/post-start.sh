#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cat <<'EOF'

✨ Dead Reckoning — 🟢 Beginner (Laying the Keel)

The platform is ready:
  • Gitea (the archives) is running in the cluster on port 30110
  • The vessel commissioning template is loaded into Backstage

▶  Start Backstage (the commission office):
     make backstage

   The UI comes up on port 3000 (first start compiles for ~30-60s).
   In a Codespace, port 7007 is made public automatically so the
   browser can reach the Backstage backend.

✅ When you think you've fixed the template, verify your work:
     make verify

EOF

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "dead-reckoning" "beginner" "06" "07" "2026"
track_container_initialized
