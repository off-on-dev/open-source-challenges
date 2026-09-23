#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/lib/scripts/tracker.sh"
set_tracking_context "accessibility-nightmare" "expert" "" "" ""
track_container_created

"${REPO_ROOT}/lib/shared/init.sh" --version v0.17.0

CHALLENGE_DIR="${REPO_ROOT}/adventures/accessibility-nightmare/expert"

echo "✨ Installing ShopSmart dependencies..."
cd "${CHALLENGE_DIR}"
npm ci

echo "✨ Installing Playwright Chromium..."
npx playwright install --with-deps chromium

echo "✅ Post-create complete."
