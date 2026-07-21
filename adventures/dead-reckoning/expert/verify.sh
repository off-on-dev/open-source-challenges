#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../../lib/scripts/loader.sh"

set_tracking_context "dead-reckoning" "expert" "06" "07" "2026"

OBJECTIVE="
- Every commission appears in the navigation log (Jaeger) as a single, connected trace, unbroken from the commission office (Backstage) through the shipyard (Argo Workflows) and the harbor master (Argo CD)
- Every vessel sails carrying the provisions it was commissioned to carry"

DOCS_URL="https://offon.dev/adventures/dead-reckoning/levels/expert"

# -----------------------------------------------------------------------------
# Environment (all pre-provisioned; see the challenge's app-config.yaml and the
# platform/ manifests).
# -----------------------------------------------------------------------------
GITEA_URL="http://localhost:30112"
GITEA_AUTH="admin:a-super-secure-password"
GITEA_ORG="fleet"

APP_NS="default"
VESSEL_PORT=8080
LOCAL_PORT=18080

print_header \
  'Dead Reckoning' \
  'The Chronometer' \
  'Verification'

# Init test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

check_prerequisites curl jq kubectl

# =============================================================================
# Precondition: the cluster must be reachable. Everything we grade lives in it
# (or in the Jaeger it feeds).
# =============================================================================
print_sub_header "Checking the fleet's harbor is reachable (cluster)..."
if ! kubectl get namespace "$APP_NS" >/dev/null 2>&1; then
  print_error_indent "The cluster isn't reachable, so there's nothing to verify yet."
  print_info "Make sure your Codespace finished starting (the platform namespaces should exist),"
  print_info "then run 'make verify' again."
  exit 1
fi
print_success_indent "Cluster is up."

# =============================================================================
# Pick the vessel to grade: the most recently touched code repo in the fleet
# org (the "-deploy" repos are its deployment manifests, not vessels). We grade
# a vessel you commissioned yourself, so you see the whole voyage in Backstage /
# Jaeger first; verification just confirms where it ended up.
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

print_info "Grading the most recently commissioned vessel: $VESSEL"

# run_check <check-fn> <args...> - runs a check; the "|| true" guard keeps a
# non-zero return from tripping set -e. Every check runs and reports on its own
# merits, so one failure never hides the other.
run_check() { "$@" || true; }

# -----------------------------------------------------------------------------
# The vessel honours its manifest: what the running service REPORTS carrying
# must match what its deployment DECLARES it was commissioned to carry. The
# declared cargo (the deployment's PROVISIONS env) is the order; we ask the
# vessel itself what it is actually carrying and compare.
# -----------------------------------------------------------------------------
check_vessel_cargo() {
  local vessel=$1 ns=$2 svc_port=$3 local_port=$4 display_name=$5 hint=$6

  print_test_section "Checking $display_name..."

  local declared
  declared=$(kubectl get deploy "$vessel" -n "$ns" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PROVISIONS")].value}' 2>/dev/null || true)
  if [[ -z "$declared" ]]; then
    print_error_indent "$display_name - the vessel's deployment declares no cargo yet"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("cargo_no_declared:$vessel")
    return
  fi

  if ! kubectl rollout status "deployment/$vessel" -n "$ns" --timeout=60s >/dev/null 2>&1; then
    print_error_indent "$display_name - deployment/$vessel never became available in '$ns'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("cargo_unavailable:$vessel")
    return
  fi

  if ! setup_port_forward "$vessel" "$ns" "$local_port" "$svc_port" >/dev/null 2>&1; then
    print_error_indent "$display_name - could not reach the vessel (port-forward failed)"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("cargo_pf_failed:$vessel")
    return
  fi

  local reported="" tries=0
  while [[ $tries -lt 10 ]]; do
    reported=$(curl -s --max-time 5 "http://localhost:$local_port/" 2>/dev/null \
      | jq -r '.provisions // empty' 2>/dev/null || echo "")
    [[ -n "$reported" ]] && break
    sleep 2
    tries=$((tries + 1))
  done

  if [[ "$reported" == "$declared" ]]; then
    print_success_indent "$display_name - commissioned for '$declared', vessel reports '$reported'"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name - commissioned for '$declared' but the vessel reports '${reported:-<empty>}'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("cargo_mismatch:$vessel")
  fi
}

# =============================================================================
# Grade the two end-states from the objective. Both run and report; the red
# check tells you which half of the log still reads false.
# =============================================================================
print_new_line
print_sub_header "Reading the navigation log for $VESSEL"

# Objective 1: the commission's trace is connected end to end (Backstage ->
# Argo Workflows -> Argo CD), not a lone commission-office fragment.
run_check check_jaeger_connected_trace \
  "commission $VESSEL" "backstage" "argo-workflows,argocd" \
  "The commission's voyage is one connected trace, office to open water" \
  "The commission office logs its part, but the voyage goes dark once the vessel leaves: the shipyard's and harbor master's spans never join this trace in Jaeger (port 30103). What carries the commission's trace context out to the delivery pipeline, and does the pipeline actually receive it off the push it reacts to?"

# Objective 2: the vessel sails with the provisions it was commissioned to
# carry (its own report matches its manifest).
run_check check_vessel_cargo \
  "$VESSEL" "$APP_NS" "$VESSEL_PORT" "$LOCAL_PORT" \
  "The vessel sails with the cargo it was commissioned to carry" \
  "The vessel arrives carrying the wrong cargo, though its papers declare the right one and every step along the way reported success. Hail it with 'make ahoi VESSEL=$VESSEL' to hear what it says it's carrying, then look at how the running service decides which cargo to report."

if [[ $TESTS_FAILED -gt 0 ]]; then
  print_new_line
  print_info "Each red check above is an independent end-state from the objective. Repair the log until it reads true, then run 'make verify' again."
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

check_submission_readiness "dead-reckoning" "expert"
