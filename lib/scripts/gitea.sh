#!/usr/bin/env bash

# gitea.sh - Helper functions for verifying Gitea state via its REST API
# https://docs.gitea.com/api/1.20/

# -----------------------------------------------------------------------------
# Low-level primitive: delete a repository (no output, no counters).
# Used for cleanup after a verification run. A missing repo returns non-zero,
# which we ignore at the call site.
# Usage: gitea_delete_repo <base_url> <auth> <org> <repo>
# -----------------------------------------------------------------------------
gitea_delete_repo() {
  local base_url=$1 auth=$2 org=$3 repo=$4
  curl -sf -u "$auth" -X DELETE "$base_url/api/v1/repos/$org/$repo" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Check that a repository exists under an org and contains a given file.
# Usage: check_gitea_repo_has_file <base_url> <auth> <org> <repo> <path> <display> <hint>
# -----------------------------------------------------------------------------
check_gitea_repo_has_file() {
  local base_url=$1 auth=$2 org=$3 repo=$4 path=$5 display_name=$6 hint=$7

  print_test_section "Checking $display_name..."

  # A single contents lookup covers both cases: if the repository was never
  # opened, this 404s just the same as a missing file.
  if curl -sf -u "$auth" "$base_url/api/v1/repos/$org/$repo/contents/$path" >/dev/null 2>&1; then
    print_success_indent "$display_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name - no '$path' at '$org/$repo' (was the repository ever created?)"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_gitea_repo_has_file:$org/$repo:$path")
  fi
}

# -----------------------------------------------------------------------------
# Assert a file in a repo (default branch) DOES contain a given string.
# Used to confirm a required line is present, e.g. a catalog-info.yaml carries
# the "argocd/app-name" annotation that wires the vessel to its deployment.
# Usage: check_gitea_file_contains <base_url> <auth> <org> <repo> <path> <needle> <display> <hint>
# -----------------------------------------------------------------------------
check_gitea_file_contains() {
  local base_url=$1 auth=$2 org=$3 repo=$4 path=$5 needle=$6 display_name=$7 hint=$8

  print_test_section "Checking $display_name..."

  local content
  content=$(curl -sf -u "$auth" "$base_url/api/v1/repos/$org/$repo/raw/$path" 2>/dev/null || echo "")

  if [[ -z "$content" ]]; then
    print_error_indent "$display_name - could not read '$path' from '$org/$repo'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("gitea_file_missing:$org/$repo:$path")
  elif echo "$content" | grep -q "$needle"; then
    print_success_indent "$display_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name - '$path' is missing '$needle'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("gitea_file_missing_content:$org/$repo:$needle")
  fi
}

# -----------------------------------------------------------------------------
# Assert a file in a repo (default branch) does NOT contain a given string.
# Used to confirm a placeholder was replaced, e.g. a deploy manifest's image tag
# is no longer ":pending" after CI bumped it.
# Usage: check_gitea_file_not_contains <base_url> <auth> <org> <repo> <path> <needle> <display> <hint>
# -----------------------------------------------------------------------------
check_gitea_file_not_contains() {
  local base_url=$1 auth=$2 org=$3 repo=$4 path=$5 needle=$6 display_name=$7 hint=$8

  print_test_section "Checking $display_name..."

  local content
  content=$(curl -sf -u "$auth" "$base_url/api/v1/repos/$org/$repo/raw/$path" 2>/dev/null || echo "")

  if [[ -z "$content" ]]; then
    print_error_indent "$display_name - could not read '$path' from '$org/$repo'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("gitea_file_missing:$org/$repo:$path")
  elif echo "$content" | grep -q "$needle"; then
    print_error_indent "$display_name - '$path' still contains '$needle'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("gitea_file_contains:$org/$repo:$needle")
  else
    print_success_indent "$display_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}
