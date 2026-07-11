#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHALLENGE_DIR="$REPO_ROOT/adventures/planned/adventure-accessibility-nightmare/beginner"

echo "✨ Starting The Accessibility Nightmare - Beginner Level"

cd "$CHALLENGE_DIR"

if ! pgrep -f "vite --host 0.0.0.0" >/dev/null 2>&1; then
  echo "✨ Starting ShopSmart on port 5173"
  nohup npm run dev > /tmp/accessibility-nightmare-vite.log 2>&1 &
fi
# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "adventure-accessibility-nightmare" "beginner" "" "TODO" "TODO"
track_container_initialized
