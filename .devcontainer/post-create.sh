#!/usr/bin/env bash
set -euo pipefail

# Fork the repo into the user's account if running inside a Codespace.
if [[ "${CODESPACES:-}" == "true" ]]; then
  gh repo fork --clone=false --remote=false || true
fi

lib/shared/init.sh --version v0.17.0 # https://github.com/charmbracelet/gum/releases

echo "→ Installing mkdocs-material..."
pip install --quiet mkdocs-material mkdocs-monorepo-plugin

echo "✓ Done! Run 'mkdocs serve' to start the docs server."

