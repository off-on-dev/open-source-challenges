#!/usr/bin/env bash

# argo.sh - Verification helpers for Argo Workflows and Argo CD state.
# Used to grade a delivery pipeline stage by stage: did the build run, did the
# GitOps controller sync it, did the workload actually come up.

# -----------------------------------------------------------------------------
# Assert the most recent Argo Workflow for a given repo reached "Succeeded".
# Polls, so it also handles a build that is still running when verify is called.
# A Failed/Error phase (or no workflow at all) stops the wait early / at timeout.
# Usage: check_argo_workflow_succeeded <namespace> <repo-name> <display> <hint> [timeout_s]
# -----------------------------------------------------------------------------
check_argo_workflow_succeeded() {
  local ns=$1 repo=$2 display_name=$3 hint=$4 timeout=${5:-240}

  print_test_section "Checking $display_name..."

  local elapsed=0 phase=""
  while [[ $elapsed -lt $timeout ]]; do
    phase=$(kubectl get workflows -n "$ns" -o json 2>/dev/null \
      | jq -r --arg v "$repo" \
          '[.items[] | select(any(.spec.arguments.parameters[]?; .name == "repo-name" and .value == $v))]
           | sort_by(.metadata.creationTimestamp) | last | .status.phase // empty' \
      2>/dev/null || echo "")
    case "$phase" in
      Succeeded | Failed | Error) break ;;
    esac
    sleep 5
    elapsed=$((elapsed + 5))
  done

  if [[ "$phase" == "Succeeded" ]]; then
    print_success_indent "$display_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name - latest build for '$repo': ${phase:-none triggered}"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("argo_workflow:$repo:${phase:-none}")
  fi
}

# -----------------------------------------------------------------------------
# Assert an Argo CD Application is both Synced and Healthy. Polls, so it tolerates
# an app that is mid-sync (e.g. the brief ImagePullBackOff before the real tag).
# Usage: check_argocd_app_synced_healthy <app-name> <display> <hint> [timeout_s]
# -----------------------------------------------------------------------------
check_argocd_app_synced_healthy() {
  local app=$1 display_name=$2 hint=$3 timeout=${4:-180}

  print_test_section "Checking $display_name..."

  local elapsed=0 sync="" health=""
  while [[ $elapsed -lt $timeout ]]; do
    sync=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
    health=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")
    [[ "$sync" == "Synced" && "$health" == "Healthy" ]] && break
    sleep 5
    elapsed=$((elapsed + 5))
  done

  if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
    print_success_indent "$display_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name - Application '$app': sync=${sync:-<none>} health=${health:-<none>}"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("argocd_app:$app:${sync:-none}/${health:-none}")
  fi
}
