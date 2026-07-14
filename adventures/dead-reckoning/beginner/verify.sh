#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../../lib/scripts/loader.sh"

set_tracking_context "dead-reckoning" "beginner" "06" "07" "2026"

OBJECTIVE="
- Commission a vessel end to end: file its repository at the location picked in the form (not a hardcoded path) so the new service is registered in the Backstage catalog
- In the commissioning form, choose the owning squadron from a picker of the catalog's squadrons, instead of typing it in by hand
- From the commissioning result, follow a working link to the new component in the catalog"

DOCS_URL="https://offon.dev/adventures/dead-reckoning/levels/beginner"

# -----------------------------------------------------------------------------
# Environment (all pre-provisioned; see the challenge's app-config.yaml)
# -----------------------------------------------------------------------------
TEMPLATE_FILE="$SCRIPT_DIR/backstage/templates/vessel-commissioning/template.yaml"
BACKSTAGE_URL="http://localhost:7007"
TEMPLATE_REF="template:default/vessel-commissioning"

GITEA_URL="http://localhost:30112"
GITEA_AUTH="admin:a-super-secure-password"
GITEA_ORG="fleet"

# A unique, disposable vessel so repeated runs never collide, and it is obvious
# in Gitea/the catalog that it came from verification.
VESSEL_NAME="hms-verify-$(date +%s)"
REPO_URL="localhost:30112?owner=${GITEA_ORG}&repo=${VESSEL_NAME}"

print_header \
  'Dead Reckoning' \
  'Laying the Keel' \
  'Verification'

# Init test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

# Clean up after the disposable verification run on exit: unregister the
# component it added (so it does not linger as a dangling catalog entry), delete
# its Gitea repo, and keep the loader's port-forward cleanup.
cleanup_verify() {
  backstage_unregister_by_target "$BACKSTAGE_URL" "$VESSEL_NAME" || true
  gitea_delete_repo "$GITEA_URL" "$GITEA_AUTH" "$GITEA_ORG" "$VESSEL_NAME" || true
  cleanup_port_forwards
}
trap cleanup_verify EXIT INT TERM

check_prerequisites curl jq

# =============================================================================
# Precondition: Backstage must be running. Verification commissions a real test
# vessel through it, so without it there is nothing to check. Exit early with a
# clear message instead of reporting a misleading set of failures.
# =============================================================================
print_sub_header "Checking the commission office is open (Backstage)..."

if ! backstage_reachable "$BACKSTAGE_URL"; then
  print_error_indent "Backstage isn't running, so there's nothing to verify yet."
  print_info "Start it in another terminal with 'make backstage' and leave it running,"
  print_info "then run 'make verify' again."
  exit 1
fi

print_success_indent "Backstage is up. Running verification checks..."

# =============================================================================
# Objective 1: A vessel commissions end to end, filed at the picked location
# =============================================================================
print_new_line
print_sub_header "Objective 1: A vessel commissions end to end at the chosen location"

# Static: the archive step must publish to the location chosen in the form,
# not a hardcoded path.
check_file_contains \
  "$TEMPLATE_FILE" \
  "parameters.repoUrl" \
  "The archive step uses the repository location from the form" \
  "Look at the 'File in the archives' step: where does it get the repository location, and where should that come from?"

# Runtime: actually run the template through the scaffolder and inspect the result.
print_step "Commissioning $VESSEL_NAME (this runs the real template)..."
backstage_commission_vessel \
  "$BACKSTAGE_URL" "$TEMPLATE_REF" \
  "$VESSEL_NAME" "group:default/windward" "home-fleet" "$REPO_URL"

check_scaffolder_task_completed \
  "The template runs from start to finish without errors" \
  "Watch the commissioning steps run in Backstage: which step stops the procedure, and what is it missing?"

check_gitea_repo_has_file \
  "$GITEA_URL" "$GITEA_AUTH" "$GITEA_ORG" "$VESSEL_NAME" "catalog-info.yaml" \
  "A repository was created in Gitea with its catalog-info.yaml" \
  "Follow the 'File in the archives' step: does it have everything it needs to create the repository?"

# =============================================================================
# Objective 2: The owning squadron is chosen from a picker (the form)
# =============================================================================
print_new_line
print_sub_header "Objective 2: The owning squadron is chosen from a picker"

check_file_contains \
  "$TEMPLATE_FILE" \
  "ui:field: OwnerPicker" \
  "The owning squadron is chosen from a picker, not typed by hand" \
  "Look at how the owning squadron is entered on the form's Fleet Assignment page, and compare it to the other fields on that page."

# =============================================================================
# Objective 3: The result links back to the vessel in the registry (the output)
# =============================================================================
print_new_line
print_sub_header "Objective 3: The result links back to the new vessel in the catalog"

check_scaffolder_output_entity_ref \
  "The result links back to the new vessel in the catalog" \
  "Look at the template's output: what should the 'Open in registry' link point at?"

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

check_submission_readiness "dead-reckoning" "beginner"
