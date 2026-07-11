#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../../../lib/scripts/loader.sh"

set_tracking_context "adventure-accessibility-nightmare" "beginner" "" "TODO" "TODO"

OBJECTIVE="
- Run Lighthouse and axe-core to identify and interpret the accessibility violations
- Fix color contrast and missing alt text on all homepage assets
- Ensure all interactive elements are keyboard accessible and have visible Focus Appearance (WCAG 2.4.11)
- Achieve a Lighthouse accessibility score of 95+ with zero critical axe-core violations"

DOCS_URL="https://offon.dev/adventures/adventure-accessibility-nightmare/levels/beginner"

print_header \
  'The Accessibility Nightmare' \
  'The Initial Audit' \
  'Verification'

# Init test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

check_prerequisites node npm jq
print_sub_header "Running verification checks..."

print_test_section "Running Playwright and axe-core accessibility checks..."
if npm run test:a11y; then
  print_success_indent "No serious or critical axe violations, and key actions are keyboard reachable"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "Playwright accessibility checks failed"
  print_hint "Fix missing alt text, contrast failures, semantic controls, keyboard access, and focus styles."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("playwright_accessibility")
fi
print_new_line

print_test_section "Checking Lighthouse accessibility score..."
if npm run test:lighthouse; then
  print_success_indent "Lighthouse accessibility score is at least 95"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "Lighthouse accessibility score is below 95"
  print_hint "Run npm run test:lighthouse and inspect the generated report for remaining issues."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("lighthouse_accessibility")
fi
print_new_line
# =============================================================================
# Summary
# =============================================================================

failed_checks_json="[]"
if [[ -n "${FAILED_CHECKS[*]:-}" ]]; then
  failed_checks_json=$(printf '%s\n' "${FAILED_CHECKS[@]}" | jq -R . | jq -s .)
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
  track_verification_completed "failed" "$failed_checks_json"
  print_verification_summary "adventure-accessibility-nightmare" "$DOCS_URL" "$OBJECTIVE"
  exit 1
fi

track_verification_completed "success" "$failed_checks_json"

print_header "Test Results Summary"
print_success "✅ PASSED: All $TESTS_PASSED verification checks passed!"
print_new_line

check_submission_readiness "adventure-accessibility-nightmare" "beginner"
