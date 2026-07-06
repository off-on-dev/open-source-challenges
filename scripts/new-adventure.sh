#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IDEAS_DIR="$REPO_ROOT/ideas"

# shellcheck source=../lib/scripts/idea-parser.sh
source "$REPO_ROOT/lib/scripts/idea-parser.sh"

# ─── Select adventure ────────────────────────────────────────────────────────

selected_slug=$(find "$IDEAS_DIR" -maxdepth 1 -name "*.md" ! -name "adventure-idea-template.md" -exec basename {} .md \; | sort \
  | gum choose --header "Which adventure do you want to scaffold?")
selected_file="$IDEAS_DIR/$selected_slug.md"
parse_adventure_header "$selected_file"

# ─── Select level ────────────────────────────────────────────────────────────

level_lines=$(grep '^### ' "$selected_file" | sed 's/^### //')
selected_level=$(echo "$level_lines" | gum choose --header "Which level do you want to scaffold?")

# ─── Parse level metadata ─────────────────────────────────────────────────────

parse_level_heading "$selected_level"

echo ""
echo "Adventure : $adventure_emoji $adventure_name ($selected_slug)"
echo "Level     : $level_emoji  $level_difficulty: $level_name"
echo "Slug      : $level_slug"
echo ""

# ─── Scaffold adventure base ──────────────────────────────────────────────────

ADVENTURE_DIR="$REPO_ROOT/adventures/planned/$selected_slug"
adventure_technologies=$(extract_overview_field "$selected_file" "Technologies")
adventure_theme=$(extract_overview_field "$selected_file" "Theme")

if [[ ! -d "$ADVENTURE_DIR" ]]; then
  echo "Creating adventure base at adventures/planned/$selected_slug/ ..."
  mkdir -p "$ADVENTURE_DIR/docs"

  cat > "$ADVENTURE_DIR/README.md" << EOF
# $adventure_emoji $adventure_name

$adventure_theme

**Technologies:** $adventure_technologies

The entire **infrastructure is pre-provisioned in your Codespace**
**You don't need to set up anything locally. Just focus on solving the problem.**

## 🚀 Ready to Start?

[Choose your level](https://offon.dev/adventures/$selected_slug/) and begin learning!
EOF

  cat > "$ADVENTURE_DIR/docs/index.yaml" << EOF
slug: $selected_slug
name: "$adventure_name"
emoji: "$adventure_emoji"

tags:
  # TODO: list technologies as separate tag items
  - TODO

backstory:
  - >-
    $adventure_theme
  # TODO: expand backstory if desired

overview:
  - >-
    TODO: brief intro (mission + key technologies + pre-provisioned note)

rewards:
  deadline: "" # TODO: fill in once the adventure goes live
  tiers:
    - label: "1st place"
      description: "TODO"
    - label: "Top 3"
      description: "TODO"
EOF

  echo "✅ Adventure base created."
else
  echo "ℹ️  Adventure base already exists, skipping."
fi

# ─── Scaffold level doc ───────────────────────────────────────────────────────

level_summary=$(extract_level_description "$selected_file" "$selected_level")
level_story=$(extract_level_section "$selected_file" "$selected_level" "Story")
level_objective=$(extract_level_section "$selected_file" "$selected_level" "Objective")
level_learnings=$(extract_level_section "$selected_file" "$selected_level" "What You'll Learn")
level_tools=$(extract_level_section "$selected_file" "$selected_level" "Tools & Infrastructure")

LEVEL_DOC="$ADVENTURE_DIR/docs/$level_slug.yaml"

if [[ ! -f "$LEVEL_DOC" ]]; then
  echo "Creating level doc at docs/$level_slug.yaml ..."

  cat > "$LEVEL_DOC" << EOF
level: $level_slug
emoji: "$level_emoji"
title: "$level_name"
devcontainer: ${selected_slug}_${level_slug}
community_url: "" # TODO: add community thread URL once the adventure is live

summary: "$level_summary"

audience: >-
  TODO: describe who this level is for

backstory:
  - >-
    $level_story
  # TODO: expand backstory if desired

objective:
  - >-
    TODO: first objective

what_you_learn:
  - >-
    TODO: first learning (link to relevant docs)

architecture:
  - >-
    TODO: describe the overall setup
  - >-
    TODO: describe what the player edits vs. leaves alone

architecture_diagram: "" # TODO: add diagram filename (e.g. $selected_slug-$level_slug.svg)

toolbox:
  - name: "TODO"
    url: "TODO"
    description: "TODO: describe what this tool is used for"

services: []

how_to_play:
  - id: explore
    title: "Explore the Setup"
    content: |
      TODO: describe how players can explore the initial state

  - id: implement
    title: "Implement the Solution"
    content: |
      TODO: describe how players implement the solution

helpful_links:
  - title: "TODO"
    url: "TODO"
    description: "TODO: describe what this link is useful for"
EOF

  echo "✅ Level doc created."
else
  echo "ℹ️  Level doc already exists, skipping."
fi

# ─── Scaffold verify.sh ───────────────────────────────────────────────────────

VERIFY_SCRIPT="$ADVENTURE_DIR/$level_slug/verify.sh"

if [[ ! -f "$VERIFY_SCRIPT" ]]; then
  echo "Creating verification script at $level_slug/verify.sh ..."
  mkdir -p "$ADVENTURE_DIR/$level_slug"

  cat > "$VERIFY_SCRIPT" << EOF
#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "\$SCRIPT_DIR/../../../../lib/scripts/loader.sh"

set_tracking_context "$selected_slug" "$level_slug" "" "TODO" "TODO"

OBJECTIVE="$level_objective"

DOCS_URL="https://offon.dev/adventures/$selected_slug/levels/$level_slug"

print_header \\
  '$adventure_name' \\
  '$level_name' \\
  'Verification'

# Init test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

check_prerequisites # TODO: list required tools (e.g. kubectl curl jq)

print_sub_header "Running verification checks..."

# TODO: add verification checks
# Examples:
#   check_jaeger_traces "service-name" "Traces present" "No traces found."
#   is_app_reachable "http://localhost:30100" "App is reachable" "App not reachable"
#   check_file_contains "file.py" "expected_string" "Check label" "Hint if it fails"

# =============================================================================
# Summary
# =============================================================================

failed_checks_json="[]"
if [[ -n "\${FAILED_CHECKS[*]:-}" ]]; then
  failed_checks_json=\$(printf '%s\n' "\${FAILED_CHECKS[@]}" | jq -R . | jq -s .)
fi

if [[ \$TESTS_FAILED -gt 0 ]]; then
  track_verification_completed "failed" "\$failed_checks_json"
  print_verification_summary "$selected_slug" "\$DOCS_URL" "\$OBJECTIVE"
  exit 1
fi

track_verification_completed "success" "\$failed_checks_json"

print_header "Test Results Summary"
print_success "✅ PASSED: All \$TESTS_PASSED verification checks passed!"
print_new_line

check_submission_readiness "$selected_slug" "$level_slug"
EOF

  chmod +x "$VERIFY_SCRIPT"
  echo "✅ Verification script created."
else
  echo "ℹ️  Verification script already exists, skipping."
fi

# ─── Scaffold devcontainer ────────────────────────────────────────────────────

DEVCONTAINER_NAME="${selected_slug}_${level_slug}"
DEVCONTAINER_DIR="$REPO_ROOT/.devcontainer/$DEVCONTAINER_NAME"

if [[ ! -d "$DEVCONTAINER_DIR" ]]; then
  echo "Creating devcontainer at .devcontainer/$DEVCONTAINER_NAME/ ..."
  mkdir -p "$DEVCONTAINER_DIR"

  cat > "$DEVCONTAINER_DIR/devcontainer.json" << EOF
{
  "name": "$adventure_emoji $adventure_name | $level_emoji $level_difficulty ($level_name)",
  "image": "mcr.microsoft.com/devcontainers/base:bullseye",
  "workspaceFolder": "/workspaces/\${localWorkspaceFolderBasename}/adventures/planned/$selected_slug/$level_slug",
  "features": {
    // TODO: add required features (e.g. "ghcr.io/devcontainers/features/docker-in-docker:2": {})
  },
  "postCreateCommand": "bash /workspaces/\${localWorkspaceFolderBasename}/.devcontainer/$DEVCONTAINER_NAME/post-create.sh",
  "postStartCommand": "bash /workspaces/\${localWorkspaceFolderBasename}/.devcontainer/$DEVCONTAINER_NAME/post-start.sh",
  "customizations": {
    "codespaces": {
      "openFiles": [
        "adventures/planned/$selected_slug/README.md"
      ],
      "permissions": {
        "codespaces": "write"
      }
    }
  },
  "forwardPorts": [],
  "portsAttributes": {
    // TODO: add port labels (e.g. "30100": { "label": "ArgoCD", "onAutoForward": "notify" })
  },
  "otherPortsAttributes": {
    "onAutoForward": "ignore"
  }
}
EOF

  cat > "$DEVCONTAINER_DIR/post-create.sh" << EOF
#!/usr/bin/env bash
set -e

REPO_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck disable=SC1091
source "\$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "$selected_slug" "$level_slug" "" "TODO" "TODO"
track_container_created

"\$REPO_ROOT/lib/shared/init.sh" --version v0.17.0

# TODO: Install and configure the tools your adventure needs using the shared setup scripts in /lib.
#       Every script accepts a --version flag or per-tool version flags (e.g. kubernetes uses
#       --kind-version, --kubectl-version, etc.) to pin a specific tool version — use this instead of
#       editing the shared script or duplicating install logic in this file.
#
#       Examples:
#         "\$REPO_ROOT/lib/argocd/init.sh" --version v3.5.0
#         "\$REPO_ROOT/lib/argocd/init.sh" --read-only --version v3.5.0
#         "\$REPO_ROOT/lib/kubernetes/init.sh" --kubectl-version v1.35.0 --helm-version v4.1.0
#
#       Run any script with --help to see all available flags and their defaults.
EOF

  cat > "$DEVCONTAINER_DIR/post-start.sh" << EOF
#!/usr/bin/env bash
set -e

REPO_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
CHALLENGE_DIR="\$REPO_ROOT/adventures/planned/$selected_slug/$level_slug"

echo "✨ Starting $adventure_name - $level_difficulty Level"

# TODO: start services & apply initial state

# shellcheck disable=SC1091
source "\$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "$selected_slug" "$level_slug" "" "TODO" "TODO"
track_container_initialized
EOF

  chmod +x "$DEVCONTAINER_DIR/post-create.sh" "$DEVCONTAINER_DIR/post-start.sh"
  echo "✅ Devcontainer created."
else
  echo "ℹ️  Devcontainer already exists, skipping."
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

gum style \
  --border rounded --border-foreground 212 \
  --padding "1 2" --margin "1 0" \
  "$(gum style --foreground 212 --bold "🎉  $adventure_emoji  $adventure_name | $level_emoji  $level_difficulty is ready!")" \
  "" \
  "Search for TODO in the generated files and fill them in:" \
  "  adventures/planned/$selected_slug/" \
  "  .devcontainer/$DEVCONTAINER_NAME/" \
  "" \
  "$(gum style --foreground 245 "Need help? Check the contributing guide:")" \
  "$(gum style --foreground 245 "https://github.com/dynatrace-oss/open-ecosystem-challenges/blob/main/CONTRIBUTING.md#build-a-new-adventure")"

