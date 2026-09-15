#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../../lib/scripts/loader.sh"

set_tracking_context "accessibility-nightmare" "intermediate" "07" "09" "2026"

OBJECTIVE="
- Complete the checkout end to end using only the keyboard.
- Have every step of that journey announced to a screen reader, including why a submission was rejected.
- Rebuild the size picker as a select-only combobox, so it exposes a role, a name and the size that is chosen.
- Keep the axe-core scan reporting no violations throughout."

DOCS_URL="https://offon.dev/adventures/accessibility-nightmare/levels/intermediate"

# The exercise is understanding what a headless UI library does for you, so the
# dependency set is fixed for the duration.
EXPECTED_DEPENDENCIES="@axe-core/playwright @guidepup/virtual-screen-reader @playwright/test @vitejs/plugin-react react react-dom vite"

print_header \
  'The Accessibility Nightmare' \
  'The Checkout Trap' \
  'Verification'

# Init test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

check_prerequisites node npm npx jq

print_sub_header "Running verification checks..."

check_npm_dependencies \
  "package.json" \
  "$EXPECTED_DEPENDENCIES" \
  "The checkout is built by hand, with no new dependencies" \
  "The dependency list is fixed for this level. If you reached for a headless UI library, that is the right call on real work and the wrong one here, because the exercise is understanding what it does for you. If you added something unrelated, it still has to come back out so everyone is solving the same problem."

check_playwright_tests \
  "@scan" \
  "The automated scan still reports no violations" \
  "This was green before you touched anything. A component that claims a role takes on a contract the scanner does check, so read what it is objecting to."

check_playwright_tests \
  "@picker" \
  "The size picker can be reached, operated and understood" \
  "Nothing tells assistive technology what the size control is, what it is called, or which size is chosen. Work out where each of those three things is supposed to come from."

check_playwright_tests \
  "@dialog" \
  "The basket confirmation keeps hold of the keyboard" \
  "Follow the keyboard through the confirmation's whole life: opening it, moving around inside it, and leaving it again. Check where it actually ends up at each of those moments."

check_playwright_tests \
  "@form" \
  "A rejected submission reaches a screen reader user" \
  "The message is already on the screen. Ask what has to be true of text that appears after the page has loaded before a screen reader will say anything about it."

check_playwright_tests \
  "@journey" \
  "The whole checkout can be completed without a mouse" \
  "Put your hands on the keyboard only and buy something. Stop at the first place you cannot get past."

# =============================================================================
# Summary
# =============================================================================

failed_checks_json="[]"
if [[ -n "${FAILED_CHECKS[*]:-}" ]]; then
  failed_checks_json=$(printf '%s\n' "${FAILED_CHECKS[@]}" | jq -R . | jq -s .)
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
  track_verification_completed "failed" "$failed_checks_json"
  print_verification_summary "accessibility-nightmare" "$DOCS_URL" "$OBJECTIVE"
  exit 1
fi

track_verification_completed "success" "$failed_checks_json"

print_header "Test Results Summary"
print_success "✅ PASSED: All $TESTS_PASSED verification checks passed!"
print_new_line

check_submission_readiness "accessibility-nightmare" "intermediate"
