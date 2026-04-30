#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../../../lib/scripts/loader.sh"

OBJECTIVE="By the end of this level, you should have:

- A SpeciesInterceptor that captures ?species= into the OpenFeature transaction context
- A global evaluation context carrying country (from the COUNTRY env var)
- An AuditHook that logs every flag evaluation
- Trial passes a 'dose' attribute as invocation context at the call site
- curl /?species=zyklop returns 'enhanced'
- curl /?dose=standard returns 'sharp' (with COUNTRY=de) and never the fallback 'untreated'
- curl /?dose=underdose returns 'clouded' (improper dosing for non-zyklops)
- curl /?species=zyklop&dose=underdose returns 'enhanced' (species priority survives bad dose)
- The application log contains audit lines emitted by AuditHook"

DOCS_URL="https://dynatrace-oss.github.io/open-ecosystem-challenges/00-blind-by-design/intermediate"

print_header \
  'Challenge 00: Blind by Design' \
  '🟡 Intermediate: Outcome by cohort' \
  'Verification'

# Init test counters
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

check_prerequisites curl jq

# -----------------------------------------------------------------------------
# Locate the application log. The participant is instructed (in intermediate.md)
# to start the app with `./mvnw spring-boot:run | tee app.log` so the log lives
# next to this script. Fall back to a couple of other reasonable spots.
# -----------------------------------------------------------------------------
APP_LOG=""
for candidate in \
  "$SCRIPT_DIR/app.log" \
  "$SCRIPT_DIR/../app.log" \
  "$PWD/app.log"; do
  if [[ -f "$candidate" ]]; then
    APP_LOG="$candidate"
    break
  fi
done

print_sub_header "Running verification checks..."

# -----------------------------------------------------------------------------
# 1. App reachable on :8080
# -----------------------------------------------------------------------------
print_test_section "Checking the lab is reachable on :8080..."
if curl -s --max-time 5 "http://localhost:8080/" >/dev/null 2>&1; then
  print_success_indent "App is reachable at http://localhost:8080/"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "App not reachable at http://localhost:8080/"
  print_hint "Start the lab with: ./run-germany.sh   (or COUNTRY=de ./mvnw spring-boot:run | tee app.log)"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("app_reachable")
fi
print_new_line

# -----------------------------------------------------------------------------
# 2. Per-subject targeting: ?species=zyklop must return "enhanced"
# -----------------------------------------------------------------------------
print_test_section "Checking the zyklop subject gets 'enhanced'..."
ZYKLOP_VALUE="$(curl -s --max-time 5 'http://localhost:8080/?species=zyklop' 2>/dev/null \
  | jq -r '.value // empty' 2>/dev/null || echo "")"

if [[ "$ZYKLOP_VALUE" == "enhanced" ]]; then
  print_success_indent "GET /?species=zyklop returned 'enhanced'"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "GET /?species=zyklop returned: '$ZYKLOP_VALUE' (expected 'enhanced')"
  print_hint "Did you wire SpeciesInterceptor and register a ThreadLocalTransactionContextPropagator?"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("species_targeting")
fi
print_new_line

# -----------------------------------------------------------------------------
# 3. Trial-country targeting: GET /?dose=standard with COUNTRY=de in the env
#    should resolve to "sharp". We pin dose=standard explicitly so the random
#    dose pick (which the controller does on the call site) cannot trip the
#    "improper dose -> clouded" branch. If the global eval context is not
#    wired, the targeting falls through to the default variant and "blurry"
#    comes back instead. The only response we truly reject is the literal
#    fallback "untreated", which means no provider is resolving at all.
# -----------------------------------------------------------------------------
print_test_section "Checking the trial-country branch fires for COUNTRY=de..."
COUNTRY_VALUE="$(curl -s --max-time 5 'http://localhost:8080/?dose=standard' 2>/dev/null \
  | jq -r '.value // empty' 2>/dev/null || echo "")"

if [[ "$COUNTRY_VALUE" == "sharp" ]]; then
  print_success_indent "GET /?dose=standard returned 'sharp' — country targeting is firing"
  TESTS_PASSED=$((TESTS_PASSED + 1))
elif [[ "$COUNTRY_VALUE" == "untreated" || -z "$COUNTRY_VALUE" ]]; then
  print_error_indent "GET /?dose=standard returned: '$COUNTRY_VALUE' — provider isn't resolving"
  print_hint "Check OpenFeatureConfig — the FlagdProvider should be registered before the first request."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("default_resolves")
else
  print_error_indent "GET /?dose=standard returned: '$COUNTRY_VALUE' (expected 'sharp' with COUNTRY=de)"
  print_hint "Did you populate the global evaluation context with country=System.getenv(\"COUNTRY\")? Did you start the lab via ./run-germany.sh or with COUNTRY=de set?"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("country_targeting")
fi
print_new_line

# -----------------------------------------------------------------------------
# 4. Invocation context: GET /?dose=underdose must return "clouded" — the
#    controller passes the participant-supplied dose at the call site, the
#    targeting catches improper doses for non-zyklop subjects.
# -----------------------------------------------------------------------------
print_test_section "Checking improper-dose targeting fires for ?dose=underdose..."
UNDERDOSE_VALUE="$(curl -s --max-time 5 'http://localhost:8080/?dose=underdose' 2>/dev/null \
  | jq -r '.value // empty' 2>/dev/null || echo "")"

if [[ "$UNDERDOSE_VALUE" == "clouded" ]]; then
  print_success_indent "GET /?dose=underdose returned 'clouded' — invocation context is firing"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "GET /?dose=underdose returned: '$UNDERDOSE_VALUE' (expected 'clouded')"
  print_hint "Does Trial.observeSubject pass an ImmutableContext with 'dose' to client.getStringDetails(...) at the call site?"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("invocation_context")
fi
print_new_line

# -----------------------------------------------------------------------------
# 5. Zyklop biology overrides bad dosing: even with ?dose=underdose, a zyklop
#    subject should still resolve to "enhanced" because the targeting puts
#    species-zyklop ahead of the improper-dose branch.
# -----------------------------------------------------------------------------
print_test_section "Checking zyklop biology survives an improper dose..."
ZYKLOP_BAD_DOSE="$(curl -s --max-time 5 'http://localhost:8080/?species=zyklop&dose=underdose' 2>/dev/null \
  | jq -r '.value // empty' 2>/dev/null || echo "")"

if [[ "$ZYKLOP_BAD_DOSE" == "enhanced" ]]; then
  print_success_indent "Zyklop + underdose returned 'enhanced' — species priority is correct"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "Zyklop + underdose returned: '$ZYKLOP_BAD_DOSE' (expected 'enhanced')"
  print_hint "Targeting order in flags.json should evaluate species=zyklop before the improper-dose branch."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("priority_species_over_dose")
fi
print_new_line

# -----------------------------------------------------------------------------
# 4. AuditHook audit lines must appear in the application log.
# -----------------------------------------------------------------------------
print_test_section "Checking AuditHook audit lines in application log..."
if [[ -z "$APP_LOG" ]]; then
  print_error_indent "Couldn't find app.log next to verify.sh"
  print_hint "Start the lab with: ./run-germany.sh   (or COUNTRY=de ./mvnw spring-boot:run | tee app.log)"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("app_log_missing")
elif grep -Eq "AUDIT|Before hook|After hook" "$APP_LOG"; then
  print_success_indent "Found AuditHook audit lines in $APP_LOG"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "No 'Before hook'/'After hook' lines found in $APP_LOG"
  print_hint "Did you implement AuditHook and register it via api.addHooks(...)?"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("custom_hook_log")
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
  print_verification_summary "blind by design" "$DOCS_URL" "$OBJECTIVE"
  exit 1
fi

track_verification_completed "success" "$failed_checks_json"

print_header "Test Results Summary"
print_success "✅ PASSED: All $TESTS_PASSED verification checks passed!"
print_new_line

# Run submission readiness checks (best-effort: the function exists in lib)
if command -v check_submission_readiness >/dev/null 2>&1; then
  check_submission_readiness "00-blind-by-design" "intermediate"
fi
