#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../../../lib/scripts/loader.sh"

OBJECTIVE="By the end of this level, you should have:
- The OpenTelemetry meter provider wired and the OpenFeature MetricsHook registered
- At least one trace for service 'fun-with-flags-java-spring' visible in Tempo
- The 'feature_flag_evaluation_requests_total' counter non-zero in Prometheus
- The 'vision_amplifier_v2' fractional rollout flipped back to 100% off / 0% on
- HTTP 5xx rate over the last minute below 1%"

DOCS_URL="https://dynatrace-oss.github.io/open-ecosystem-challenges/00-blind-by-design/expert"

print_header \
  'Adventure 00: Blind by Design' \
  '🔴 Expert: Phase 3 — read the chart' \
  'Verification'

check_prerequisites curl jq

print_sub_header "Running verification checks..."

TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

APP_URL="http://localhost:8080"
FLAGD_HTTP="http://localhost:8013"
PROMETHEUS_URL="http://localhost:9090"
TEMPO_URL="http://localhost:3200"
GRAFANA_URL="http://localhost:3000"

# ---- 1. App reachable ------------------------------------------------------
print_test_section "Checking lab reachability"
if curl -fsS --max-time 5 "$APP_URL/" >/dev/null 2>&1; then
  print_info_indent "✓ Spring Boot lab reachable at $APP_URL"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "Spring Boot lab is not reachable at $APP_URL"
  print_hint "Start the app with: ./mvnw spring-boot:run"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("app_reachable")
fi
print_new_line

# ---- 2. flagd reachable ---------------------------------------------------
print_test_section "Checking flagd reachability"
if curl -fsS --max-time 5 -X POST "$FLAGD_HTTP/flagd.evaluation.v1.Service/ResolveBoolean" \
     -H 'Content-Type: application/json' \
     -d '{"flagKey":"loadgen_active","context":{}}' >/dev/null 2>&1; then
  print_info_indent "✓ flagd HTTP eval API reachable at $FLAGD_HTTP"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "flagd HTTP API is not reachable at $FLAGD_HTTP"
  print_hint "flagd is a sibling devcontainer service. Reopen the Codespace if it is not running."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("flagd_reachable")
fi
print_new_line

# ---- 3. LGTM stack reachable ---------------------------------------------
print_test_section "Checking Grafana LGTM stack reachability"
if curl -fsS --max-time 5 "$GRAFANA_URL/api/health" >/dev/null 2>&1; then
  print_info_indent "✓ Grafana reachable at $GRAFANA_URL"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  print_error_indent "Grafana is not reachable at $GRAFANA_URL"
  print_hint "The LGTM stack is a sibling devcontainer service (lgtm). Reopen the Codespace if it is not running."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("lgtm_reachable")
fi
print_new_line

# ---- 4. vision_amplifier_v2 rolled back -----------------------------------
print_test_section "Checking vision_amplifier_v2 rollback"
ROLLOUT_RESPONSE=$(curl -fsS --max-time 5 -X POST \
  "$FLAGD_HTTP/flagd.evaluation.v1.Service/ResolveBoolean" \
  -H 'Content-Type: application/json' \
  -d '{"flagKey":"vision_amplifier_v2","context":{"targetingKey":"verify-probe-user"}}' 2>/dev/null || echo "")

if [[ -z "$ROLLOUT_RESPONSE" ]]; then
  print_error_indent "Could not query vision_amplifier_v2 from flagd"
  print_hint "Make sure the flagd container is running and flags.json has vision_amplifier_v2 defined."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("vision_amplifier_v2_rollback")
else
  ROLLOUT_VALUE=$(echo "$ROLLOUT_RESPONSE" | jq -r '.value // empty')
  if [[ "$ROLLOUT_VALUE" == "false" ]]; then
    print_info_indent "✓ vision_amplifier_v2 evaluates to false (rollout has been rolled back)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "vision_amplifier_v2 still resolves to '$ROLLOUT_VALUE' for the probe user"
    print_hint "Edit flags.json: flip the fractional bucket so 'off' is 100 and 'on' is 0, save, and flagd will pick it up."
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("vision_amplifier_v2_rollback")
  fi
fi
print_new_line

# ---- 5. Prometheus has feature_flag_evaluation_requests_total ----------
print_test_section "Checking feature_flag metrics in Prometheus"
PROM_QUERY='feature_flag_evaluation_requests_total'
PROM_RESPONSE=$(curl -fsS --max-time 5 -G "$PROMETHEUS_URL/api/v1/query" \
  --data-urlencode "query=$PROM_QUERY" 2>/dev/null || echo "")

if [[ -z "$PROM_RESPONSE" ]]; then
  print_error_indent "Could not query Prometheus at $PROMETHEUS_URL"
  print_hint "The grafana/otel-lgtm container exposes Prometheus on port 9090. If port 9090 is not forwarded, the lgtm sibling container has not started — reopen the Codespace."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("prometheus_metrics")
else
  RESULT_COUNT=$(echo "$PROM_RESPONSE" | jq '.data.result | length // 0')
  TOTAL=$(echo "$PROM_RESPONSE" | jq -r '[.data.result[]?.value[1] | tonumber] | add // 0')
  # `add // 0` is a tiny safeguard if the array is empty.
  if [[ "$RESULT_COUNT" -gt 0 ]] && awk -v v="$TOTAL" 'BEGIN { exit !(v+0 > 0) }'; then
    print_info_indent "✓ feature_flag_evaluation_requests_total is non-zero (sum=$TOTAL)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "feature_flag_evaluation_requests_total is missing or zero"
    print_hint "Wire the OpenTelemetry meter provider AND register MetricsHook in OpenFeatureConfig.initProvider(). Then drive traffic by flipping loadgen_active to 'on'."
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("prometheus_metrics")
  fi
fi
print_new_line

# ---- 6. Tempo has at least one trace for the service -------------------
print_test_section "Checking traces in Tempo"
TEMPO_RESPONSE=$(curl -fsS --max-time 5 -G "$TEMPO_URL/api/search" \
  --data-urlencode 'tags=service.name=fun-with-flags-java-spring' \
  --data-urlencode 'limit=20' 2>/dev/null || echo "")

if [[ -z "$TEMPO_RESPONSE" ]]; then
  print_error_indent "Could not query Tempo at $TEMPO_URL"
  print_hint "The grafana/otel-lgtm container exposes Tempo on port 3200. If port 9090 is not forwarded, the lgtm sibling container has not started — reopen the Codespace."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("tempo_traces")
else
  TRACE_COUNT=$(echo "$TEMPO_RESPONSE" | jq '.traces | length // 0')
  if [[ "$TRACE_COUNT" -gt 0 ]]; then
    print_info_indent "✓ Tempo has $TRACE_COUNT trace(s) for service 'fun-with-flags-java-spring'"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "Tempo has no traces for service 'fun-with-flags-java-spring'"
    print_hint "Send some traffic: curl http://localhost:8080/?userId=demo and wait a few seconds for the exporter to flush."
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("tempo_traces")
  fi
fi
print_new_line

# ---- 6b. Tempo spans carry the dose context attribute ------------------
# Generate a deterministic underdose request, give the exporter a moment to
# flush, then query Tempo for spans with feature_flag.context.dose. If the
# attribute is missing the participant has not registered the
# ContextSpanHook (or it is not reading the merged eval context).
print_test_section "Checking flag-context attributes on Tempo spans"
curl -s --max-time 5 'http://localhost:8080/?dose=underdose' >/dev/null 2>&1 || true
sleep 6  # OTel batch span processor flush window
DOSE_TEMPO=$(curl -fsS --max-time 5 -G "$TEMPO_URL/api/search" \
  --data-urlencode 'tags=feature_flag.context.dose=underdose' \
  --data-urlencode 'limit=5' 2>/dev/null || echo "")

if [[ -z "$DOSE_TEMPO" ]]; then
  print_error_indent "Could not query Tempo for context attributes"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("tempo_context")
else
  DOSE_COUNT=$(echo "$DOSE_TEMPO" | jq '.traces | length // 0')
  if [[ "$DOSE_COUNT" -gt 0 ]]; then
    print_info_indent "✓ Tempo has $DOSE_COUNT span(s) tagged feature_flag.context.dose=underdose"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "No spans with feature_flag.context.dose=underdose found in Tempo"
    print_hint "Did you register the ContextSpanHook that copies merged-eval-context attrs onto Span.current()?"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("tempo_context")
  fi
fi
print_new_line

# ---- 7. HTTP 5xx rate under threshold ----------------------------------
print_test_section "Checking HTTP 5xx error rate (last 1m)"
ERROR_QUERY='sum(rate(http_server_request_duration_seconds_count{http_response_status_code=~"5.."}[1m])) / clamp_min(sum(rate(http_server_request_duration_seconds_count[1m])), 1e-9)'
ERROR_RESPONSE=$(curl -fsS --max-time 5 -G "$PROMETHEUS_URL/api/v1/query" \
  --data-urlencode "query=$ERROR_QUERY" 2>/dev/null || echo "")

if [[ -z "$ERROR_RESPONSE" ]]; then
  # Fallback: try the older Spring metric name
  ERROR_QUERY_ALT='sum(rate(http_server_requests_seconds_count{status=~"5.."}[1m])) / clamp_min(sum(rate(http_server_requests_seconds_count[1m])), 1e-9)'
  ERROR_RESPONSE=$(curl -fsS --max-time 5 -G "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=$ERROR_QUERY_ALT" 2>/dev/null || echo "")
fi

if [[ -z "$ERROR_RESPONSE" ]]; then
  print_error_indent "Could not query Prometheus for HTTP error rate"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("error_rate")
else
  ERROR_RATE=$(echo "$ERROR_RESPONSE" | jq -r '.data.result[0].value[1] // "0"')
  # Treat NaN (no requests at all) as a pass — there's no traffic to fail on.
  if [[ "$ERROR_RATE" == "NaN" ]]; then
    print_info_indent "✓ No traffic in the last minute — error rate not meaningful (treated as pass)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  elif awk -v v="$ERROR_RATE" 'BEGIN { exit !(v+0 < 0.01) }'; then
    PERCENT=$(awk -v v="$ERROR_RATE" 'BEGIN { printf "%.2f", v*100 }')
    print_info_indent "✓ HTTP 5xx rate is ${PERCENT}% (< 1%)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    PERCENT=$(awk -v v="$ERROR_RATE" 'BEGIN { printf "%.2f", v*100 }')
    print_error_indent "HTTP 5xx rate is ${PERCENT}% (>= 1%)"
    print_hint "The 'on' bucket of vision_amplifier_v2 throws 5xx 10% of the time. Roll the rollout back to 100% off."
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("error_rate")
  fi
fi
print_new_line

print_verification_summary "Phase 3 — read the chart" "$DOCS_URL" "$OBJECTIVE"

if [[ $TESTS_FAILED -ne 0 ]]; then
  exit 1
fi
