#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "00-blind-by-design" "intermediate"
track_codespace_created

"$REPO_ROOT/lib/shared/init.sh" --version v0.17.0 # https://github.com/charmbracelet/gum/releases

# jq is needed by verify.sh; the Java devcontainer image is debian-based.
if ! command -v jq >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends jq
fi

CHALLENGE_DIR="$REPO_ROOT/adventures/planned/00-blind-by-design/intermediate"

# Make the Maven wrapper executable so the participant can just `./mvnw ...`
if [[ -f "$CHALLENGE_DIR/mvnw" ]]; then
  chmod +x "$CHALLENGE_DIR/mvnw"
fi

echo "✨ Pre-warming the Maven dependency cache so the first ./mvnw is fast..."
( cd "$CHALLENGE_DIR" && ./mvnw -q -DskipTests dependency:go-offline ) || \
  echo "⚠️  Dependency pre-warm skipped (network or wrapper not ready yet)"

echo "✅ Post-create complete."
