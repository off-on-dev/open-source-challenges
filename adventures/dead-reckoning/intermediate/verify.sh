#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../../lib/scripts/loader.sh"

set_tracking_context "dead-reckoning" "intermediate" "06" "07" "2026"

OBJECTIVE="
- A commissioned vessel is fully delivered: its code and deployment repositories exist, its delivery workflow has completed, its Argo CD Application is synced, and its service is running in the cluster
- See the vessel's live deployment status on its page in Backstage
- The vessel's service is reachable directly and reports itself seaworthy"

DOCS_URL="https://offon.dev/adventures/dead-reckoning/levels/intermediate"

# -----------------------------------------------------------------------------
# Environment (all pre-provisioned; see the challenge's app-config.yaml and the
# platform/ manifests).
# -----------------------------------------------------------------------------
GITEA_URL="http://localhost:30112"
GITEA_AUTH="admin:a-super-secure-password"
GITEA_ORG="fleet"

WORKFLOW_NS="argo-workflows"
APP_NS="default"
LOCAL_PORT=18080

print_header \
  'Dead Reckoning' \
  'Sea Trial' \
  'Verification'

# Init test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

check_prerequisites curl jq kubectl

# =============================================================================
# Precondition: the cluster must be reachable. Everything we grade lives in it.
# =============================================================================
print_sub_header "Checking the fleet's harbor is reachable (cluster)..."
if ! kubectl get namespace "$WORKFLOW_NS" >/dev/null 2>&1; then
  print_error_indent "The cluster isn't reachable, so there's nothing to verify yet."
  print_info "Make sure your Codespace finished starting (the platform namespaces should exist),"
  print_info "then run 'make verify' again."
  exit 1
fi
print_success_indent "Cluster is up."

# =============================================================================
# Pick the vessel to grade: the most recently touched code repo in the fleet
# org (the "-deploy" repos are its deployment manifests, not vessels). We grade
# a vessel you commissioned yourself, so you see the whole flow in Backstage /
# Gitea / Argo first; verification just confirms where it ended up.
# =============================================================================
repos_json=$(curl -sf -u "$GITEA_AUTH" "$GITEA_URL/api/v1/orgs/$GITEA_ORG/repos?limit=50" 2>/dev/null || echo "[]")
VESSEL=$(echo "$repos_json" \
  | jq -r 'if type == "array"
             then ([.[] | select(.name | endswith("-deploy") | not)] | max_by(.updated_at).name // empty)
             else empty end' 2>/dev/null || echo "")

if [[ -z "$VESSEL" ]]; then
  print_new_line
  print_info "No vessel found in the fleet archives yet, so there's nothing to grade."
  print_info "Commission one first: run 'make backstage', open port 3000, and run the"
  print_info "'Commission a Vessel' template. Watch it sail, then run 'make verify' again."
  exit 1
fi

DEPLOY_REPO="${VESSEL}-deploy"
print_info "Grading the most recently commissioned vessel: $VESSEL"

# =============================================================================
# Grade the pipeline stage by stage. Every stage runs and reports, so you see
# the whole picture; the first red check is where the vessel ran aground.
# =============================================================================
print_new_line
print_sub_header "Tracing the vessel from the commission office to open water"

# run_check <check-fn> <args...> - runs a stage; the "|| true" guard keeps a
# non-zero return from tripping set -e. Every stage runs and reports on its own
# merits, so an earlier failure never hides or weakens a later check.
run_check() { "$@" || true; }

# Stage 1: both repositories were filed in the archives (Gitea).
run_check check_gitea_repo_has_file \
  "$GITEA_URL" "$GITEA_AUTH" "$GITEA_ORG" "$VESSEL" "catalog-info.yaml" \
  "The vessel's code repository was opened in the fleet archives" \
  "The commission office files two sets of papers: the vessel's code and its deployment orders. Check the fleet org in Gitea: were both repositories opened?"

run_check check_gitea_repo_has_file \
  "$GITEA_URL" "$GITEA_AUTH" "$GITEA_ORG" "$DEPLOY_REPO" "deployment.yaml" \
  "The vessel's deployment repository was opened in the fleet archives" \
  "The deployment orders live in the '-deploy' repository. Is it there, with its manifests?"

# Stage 2: the vessel's catalog entry is wired to its Argo CD deployment, so its
# page in Backstage can show the deployment's status. (The vessel still deploys
# without this; only the cockpit view is blind.)
run_check check_gitea_file_contains \
  "$GITEA_URL" "$GITEA_AUTH" "$GITEA_ORG" "$VESSEL" "catalog-info.yaml" \
  "argocd/app-name: ${VESSEL}-deploy" \
  "The vessel's page is wired to its Argo CD deployment" \
  "The vessel deploys, but its page in Backstage can't find its deployment. What does the commission office need to record on the vessel's catalog entry so Backstage knows which Argo CD application belongs to it?"

# Stage 3: a delivery workflow ran and succeeded.
run_check check_argo_workflow_succeeded \
  "$WORKFLOW_NS" "$VESSEL" \
  "The delivery workflow built and delivered the vessel" \
  "Filing code in the archives should summon the shipyard. Open the Argo Workflows UI (port 30113): did a build run for this vessel, how far did it get, and what does the failed step report?" \
  10

# Stage 4: the deploy repo's image tag was bumped off the ":pending" placeholder.
run_check check_gitea_file_not_contains \
  "$GITEA_URL" "$GITEA_AUTH" "$GITEA_ORG" "$DEPLOY_REPO" "deployment.yaml" ":pending" \
  "The deployment orders point at the freshly built image, not the placeholder" \
  "The shipyard's last act is to stamp the real image onto the deployment orders. Inspect the '-deploy' repository: is it still pointing at a phantom image?"

# Stage 5: Argo CD created and reconciled an Application for the vessel.
run_check check_argocd_app_synced_healthy \
  "$DEPLOY_REPO" \
  "The harbor master synced the vessel into the fleet" \
  "The harbor master (Argo CD, port 30100) watches the archives and keeps the fleet in formation. Is there an Application for this vessel, and is it synced and healthy?" \
  30

# Stage 6: the workload is up and answers as seaworthy.
run_check check_deployment_serves \
  "$VESSEL" "$APP_NS" 8080 "$LOCAL_PORT" '"status":"seaworthy"' \
  "The vessel is under way and reports itself seaworthy" \
  "A synced deployment still has to answer the helm. Check the vessel's pod and service: does it respond, and what does it report?" \
  10

if [[ $TESTS_FAILED -gt 0 ]]; then
  print_new_line
  print_info "The pipeline runs aground at the first red check above (the stages run in order). Fix that integration point, then run 'make verify' again."
fi

# =============================================================================
# Summary
# =============================================================================

failed_checks_json="[]"
if [[ -n "${FAILED_CHECKS[*]:-}" ]]; then
  failed_checks_json=$(printf '%s\n' "${FAILED_CHECKS[@]}" | jq -R . | jq -s .)
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
  track_verification_completed "failed" "$failed_checks_json"
  print_verification_summary "dead-reckoning" "$DOCS_URL" "$OBJECTIVE"
  exit 1
fi

track_verification_completed "success" "$failed_checks_json"

print_header "Test Results Summary"
print_success "✅ PASSED: All $TESTS_PASSED verification checks passed!"
print_new_line

check_submission_readiness "dead-reckoning" "intermediate"
