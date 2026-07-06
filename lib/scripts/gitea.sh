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
    print_error_indent "$display_name - no '$path' at '$org/$repo' (was the repository ever opened?)"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_gitea_repo_has_file:$org/$repo:$path")
  fi
}
