#!/usr/bin/env bash

# jaeger.sh - Shared library for Jaeger trace checks
# This library provides functions to check for traces in Jaeger

JAEGER_API_URL="${JAEGER_API_URL:-http://localhost:30103/api}"

# -----------------------------------------------------------------------------
# Check if traces exist for a specific service
# Usage: check_jaeger_traces "service-name" "Display Name" "Hint message"
# -----------------------------------------------------------------------------
check_jaeger_traces() {
  local service_name=$1
  local display_name=$2
  local hint=$3

  print_test_section "Checking traces for $display_name..."

  # Query Jaeger API for traces
  local response
  response=$(curl -s "${JAEGER_API_URL}/traces?service=${service_name}&limit=1" 2>/dev/null || echo "")

  # Check if we got a valid JSON response with data
  if [[ -z "$response" ]]; then
    print_error_indent "Could not connect to Jaeger API at $JAEGER_API_URL"
    print_hint "Ensure Jaeger is running and port 30103 is accessible"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_jaeger_traces:connection_failed")
  else
    # Check if data array is not empty using jq
    local trace_count
    trace_count=$(echo "$response" | jq '.data | length' 2>/dev/null || echo "0")

    if [[ "$trace_count" -gt 0 ]]; then
      print_success_indent "Found traces for $service_name"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_error_indent "No traces found for $service_name"
      print_hint "$hint"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      FAILED_CHECKS+=("check_jaeger_traces:$service_name")
    fi
  fi
}

# -----------------------------------------------------------------------------
# Check if a specific span exists with a specific attribute
# Usage: check_jaeger_span_attribute "service-name" "span-name" "attribute-key" "Display Name" "Hint message"
# -----------------------------------------------------------------------------
check_jaeger_span_attribute() {
  local service_name=$1
  local span_name=$2
  local attribute_key=$3
  local display_name=$4
  local hint=$5

  print_test_section "Checking span attribute for $display_name..."

  # Query Jaeger API for traces
  local response
  response=$(curl -s "${JAEGER_API_URL}/traces?service=${service_name}&limit=5" 2>/dev/null || echo "")

  if [[ -z "$response" ]]; then
    print_error_indent "Could not connect to Jaeger API"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_jaeger_span_attribute:connection_failed")
    return
  fi

  # Check if the span exists and has the attribute
  # We look through all traces, all spans, find the one with operationName == span_name
  # and check if it has a tag with key == attribute_key
  local has_attribute
  has_attribute=$(echo "$response" | jq -r --arg span "$span_name" --arg attr "$attribute_key" '
    .data[].spans[]
    | select(.operationName == $span)
    | .tags[]
    | select(.key == $attr)
    | .key
  ' | head -n 1)

  if [[ "$has_attribute" == "$attribute_key" ]]; then
    print_success_indent "Found span '$span_name' with attribute '$attribute_key'"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "Could not find span '$span_name' with attribute '$attribute_key'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_jaeger_span_attribute:$span_name:$attribute_key")
  fi
}

# -----------------------------------------------------------------------------
# Check that a trace is connected end to end. Locates the trace whose root
# operation is $root_op (emitted by $root_service), then confirms that same
# trace also carries spans from every service in $required_services (a comma-
# separated list). Fails when the downstream spans are missing, i.e. the trace
# exists but is not connected across service boundaries.
#
# Note: the /traces search returns complete traces (all spans, every service),
# so a single query is enough to see whether the downstream legs joined.
#
# Usage:
#   check_jaeger_connected_trace \
#     "commission hms-nyx" "backstage" "argo-workflows,argocd" \
#     "Display Name" "Hint message"
# -----------------------------------------------------------------------------
check_jaeger_connected_trace() {
  local root_op=$1 root_service=$2 required_services=$3 display_name=$4 hint=$5

  print_test_section "Checking $display_name..."

  # The downstream spans may reach Jaeger a moment after the workflow finishes,
  # so give the trace a few tries to show up complete.
  local response tries=0 trace_count=0
  while [[ $tries -lt 10 ]]; do
    response=$(curl -s -G "${JAEGER_API_URL}/traces" \
      --data-urlencode "service=${root_service}" \
      --data-urlencode "operation=${root_op}" \
      --data-urlencode "limit=20" 2>/dev/null || echo "")
    trace_count=$(echo "$response" | jq '.data | length' 2>/dev/null || echo "0")
    [[ "$trace_count" -gt 0 ]] && break
    sleep 3
    tries=$((tries + 1))
  done

  if [[ -z "$response" ]]; then
    print_error_indent "Could not connect to Jaeger API at $JAEGER_API_URL"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_jaeger_connected_trace:jaeger_unreachable")
    return
  fi

  if [[ "$trace_count" -eq 0 ]]; then
    print_error_indent "No '$root_op' trace found from $root_service"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_jaeger_connected_trace:no_root_trace")
    return
  fi

  # Which services show up in the matching trace(s)?
  local present
  present=$(echo "$response" | jq -r '[.data[].processes[].serviceName] | unique | .[]' 2>/dev/null || echo "")

  local missing="" s
  IFS=',' read -ra _required <<< "$required_services"
  for s in "${_required[@]}"; do
    if ! printf '%s\n' "$present" | grep -qx "$s"; then
      missing="${missing:+$missing, }$s"
    fi
  done

  if [[ -z "$missing" ]]; then
    print_success_indent "'$root_op' is one connected trace ($required_services all present)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "'$root_op' trace is missing its downstream leg: no spans from $missing"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("check_jaeger_connected_trace:missing:$missing")
  fi
}
