#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHALLENGE_DIR="$REPO_ROOT/adventures/planned/00-blind-by-design/beginner"

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "00-blind-by-design" "beginner"
track_codespace_created

# Install gum (used by the verify.sh output helpers).
"$REPO_ROOT/lib/shared/init.sh" --version v0.17.0 # https://github.com/charmbracelet/gum/releases

# jq is needed by verify.sh; the Java devcontainer image is debian-based.
if ! command -v jq >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends jq
fi

# Java 21 is provided by the devcontainer image (mcr.microsoft.com/devcontainers/java:1-21-bullseye).
# Pre-fetch Maven dependencies so the IDE is responsive immediately.
echo "✨ Resolving Maven dependencies for the lab..."
cd "$CHALLENGE_DIR"
chmod +x ./mvnw
./mvnw -q -B -DskipTests dependency:go-offline || true

echo "✅ Post-create complete."
