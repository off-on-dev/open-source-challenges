#!/usr/bin/env bash

# backstage.sh - Helpers for driving the Backstage scaffolder API
# https://backstage.io/docs/features/software-templates/
#
# These helpers assume Backstage's default auth policy is disabled
# (backend.auth.dangerouslyDisableDefaultAuthPolicy + permission.enabled: false),
# so the scaffolder and catalog APIs accept unauthenticated requests.

# -----------------------------------------------------------------------------
# Primitive: is the Backstage backend reachable? Returns 0/1, no output, no
# counters. Used as a precondition gate before any runtime checks run.
# Usage: backstage_reachable <backend_url>
# -----------------------------------------------------------------------------
backstage_reachable() {
  local backend_url=$1
  curl -sf --max-time 5 "$backend_url/api/catalog/entities?limit=1" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Best-effort cleanup: delete any catalog location whose target contains the
# given substring, which cascades to the entities that location provided. Used
# to remove the component a verification run registered, so it does not linger
# as a dangling entry after its Gitea repo is deleted. No output, no counters.
# Usage: backstage_unregister_by_target <backend_url> <target_substring>
# -----------------------------------------------------------------------------
backstage_unregister_by_target() {
  local backend_url=$1 needle=$2

  local ids
  ids=$(curl -sf "$backend_url/api/catalog/locations" 2>/dev/null \
    | jq -r --arg n "$needle" \
        '.[] | select(.data.target != null and (.data.target | contains($n))) | .data.id' \
        2>/dev/null || echo "")

  local id
  for id in $ids; do
    curl -sf -X DELETE "$backend_url/api/catalog/locations/$id" >/dev/null 2>&1 || true
  done
}

# -----------------------------------------------------------------------------
# Primitive: run the vessel commissioning template end to end and poll the task
# to a terminal state. Does not print or touch counters; the check_* helpers
# below assert on the globals it sets.
#
# Sets globals:
#   TASK_ID      - the scaffolder task id (empty if the task could not be created)
#   TASK_STATUS  - completed | failed | cancelled | processing | not-created | unknown
#   TASK_OUTPUT  - the task output object (JSON), including resolved output.links
#
# Usage: backstage_commission_vessel <backend_url> <template_ref> <name> <owner> <system> <repo_url> [timeout_s]
# -----------------------------------------------------------------------------
backstage_commission_vessel() {
  local backend_url=$1 template_ref=$2 name=$3 owner=$4 system=$5 repo_url=$6 timeout=${7:-120}

  TASK_ID=""
  TASK_STATUS="unknown"
  TASK_OUTPUT="{}"

  local body
  body=$(jq -n \
    --arg ref "$template_ref" \
    --arg name "$name" \
    --arg owner "$owner" \
    --arg system "$system" \
    --arg repoUrl "$repo_url" \
    '{templateRef: $ref, values: {
        name: $name,
        lifecycle: "production",
        description: "Automated verification vessel - safe to delete",
        owner: $owner,
        system: $system,
        repoUrl: $repoUrl
      }}')

  local create_resp
  create_resp=$(curl -sf -X POST "$backend_url/api/scaffolder/v2/tasks" \
    -H "Content-Type: application/json" -d "$body" 2>/dev/null || echo "")
  TASK_ID=$(echo "$create_resp" | jq -r '.id // empty' 2>/dev/null || echo "")

  if [[ -z "$TASK_ID" ]]; then
    TASK_STATUS="not-created"
    return 0
  fi

  local elapsed=0 task_json
  while [[ $elapsed -lt $timeout ]]; do
    task_json=$(curl -sf "$backend_url/api/scaffolder/v2/tasks/$TASK_ID" 2>/dev/null || echo "")
    TASK_STATUS=$(echo "$task_json" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
    case "$TASK_STATUS" in
      completed | failed | cancelled) break ;;
    esac
    sleep 3
    elapsed=$((elapsed + 3))
  done

  # The resolved output (with output.links) is carried on the 'completion' event.
  local events
  events=$(curl -sf "$backend_url/api/scaffolder/v2/tasks/$TASK_ID/events" 2>/dev/null || echo "[]")
  TASK_OUTPUT=$(echo "$events" | jq -c '[.[] | select(.type == "completion") | .body.output] | last // {}' 2>/dev/null || echo "{}")
}

# -----------------------------------------------------------------------------
# Assert the last commissioning task completed without errors.
# Reads globals set by backstage_commission_vessel.
# Usage: check_scaffolder_task_completed <display> <hint>
# -----------------------------------------------------------------------------
check_scaffolder_task_completed() {
  local display_name=$1 hint=$2

  print_test_section "Checking $display_name..."

  if [[ "$TASK_STATUS" == "completed" ]]; then
    print_success_indent "$display_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name - task status: $TASK_STATUS"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_scaffolder_task_completed:$TASK_STATUS")
  fi
}

# -----------------------------------------------------------------------------
# Assert the task output contains a link with a non-empty entityRef (the
# "Open in registry" link that points at the newly registered component).
# Reads globals set by backstage_commission_vessel.
# Usage: check_scaffolder_output_entity_ref <display> <hint>
# -----------------------------------------------------------------------------
check_scaffolder_output_entity_ref() {
  local display_name=$1 hint=$2

  print_test_section "Checking $display_name..."

  local entity_ref
  entity_ref=$(echo "$TASK_OUTPUT" | jq -r '[.links[]? | select(.entityRef != null and .entityRef != "") | .entityRef] | .[0] // empty' 2>/dev/null || echo "")

  if [[ -n "$entity_ref" ]]; then
    print_success_indent "$display_name -> $entity_ref"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name - no working link back to the component"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_scaffolder_output_entity_ref")
  fi
}
