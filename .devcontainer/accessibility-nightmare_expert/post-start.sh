#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHALLENGE_DIR="${REPO_ROOT}/adventures/accessibility-nightmare/expert"

echo "✨ Starting The Accessibility Nightmare - Expert Level"

cd "${CHALLENGE_DIR}"

LOG_FILE="/tmp/accessibility-nightmare-vite.log"

if ! pgrep -f "vite --host 0.0.0.0" >/dev/null 2>&1; then
  echo "✨ Starting ShopSmart on port 5173"
  setsid nohup npm run dev </dev/null >"${LOG_FILE}" 2>&1 &
  disown 2>/dev/null || true
fi

for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:5173 >/dev/null; then
    echo "✅ ShopSmart is running on port 5173"
    break
  fi
  sleep 1
done

if ! curl --fail --silent http://127.0.0.1:5173 >/dev/null; then
  echo "❌ ShopSmart failed to start."
  if [[ -f "${LOG_FILE}" ]]; then
    tail -n 20 "${LOG_FILE}"
  fi
  echo "Run 'npm run dev' from the expert directory to start it manually."
  exit 1
fi

echo ""
echo "🛒 Open the Ports tab, click ShopSmart on 5173."
echo "   The compliance gate is in tests/compliance.spec.js — run it with:"
echo "     npm run test:a11y"
echo ""

# shellcheck disable=SC1091
source "${REPO_ROOT}/lib/scripts/tracker.sh"
set_tracking_context "accessibility-nightmare" "expert" "" "" ""
track_container_initialized
