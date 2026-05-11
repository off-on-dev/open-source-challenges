#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Fork the repo into the user's account if running inside a Codespace.
if [[ "${CODESPACES:-}" == "true" ]]; then
  gh repo fork --clone=false --remote=false || true
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "02-building-cloudhaven" "intermediate"
track_codespace_created

"$REPO_ROOT/lib/shared/init.sh" --version v0.17.0 # https://github.com/charmbracelet/gum/releases

"$REPO_ROOT/lib/open-tofu/init.sh" --version v1.11.2 # https://github.com/opentofu/opentofu/releases
"$REPO_ROOT/lib/gcp-api-mock/init.sh" --version v1.1.4 # https://github.com/KatharinaSick/gcp-api-mock/releases