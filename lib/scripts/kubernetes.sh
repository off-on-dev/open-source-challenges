#!/usr/bin/env bash

# kubernetes.sh - Shared library for Kubernetes resource checks
# This library provides functions to check k8s resources and application health

# Array to track port-forward PIDs for cleanup
declare -a PF_PIDS=()

# Check if a namespace exists
# Usage: namespace_exists "namespace-name"
# Returns: 0 if exists, 1 if not
namespace_exists() {
  if ! kubectl get namespace "$1" &> /dev/null; then
    return 1
  fi
  return 0
}

# Check if a service exists
# Usage: service_exists "service_name" "namespace-name"
# Returns: 0 if exists, 1 if not
service_exists() {
  if ! kubectl -n "$2" get service "$1" &> /dev/null; then
    return 1
  fi
  return 0
}

# Check if a resource exists
# Usage: resource_exists "type" "name" "namespace"
# Returns: 0 if exists, 1 if not
resource_exists() {
  if ! kubectl -n "$3" get $1 "$2" &> /dev/null; then
    return 1
  fi
  return 0
}

# Check if a resource has the expected version
# Usage: check_resource_version_exists "resource-type" "resource-name" "namespace" "expected-version"
# Returns: 0 if version matches, 1 if not
check_resource_version_exists() {
  local resource_type=$1
  local resource_name=$2
  local ns=$3
  local expected_version=$4

  # Check if resource exists first
  if ! resource_exists "$resource_type" "$resource_name" "$ns"; then
    return 1
  fi

  # Get the image from the resource spec
  local image
  image=$(kubectl get "$resource_type" "$resource_name" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  if [ -z "$image" ]; then
    return 1
  fi

  if [[ "$image" == *"$expected_version"* ]]; then
    return 0
  else
    return 1
  fi
}

# Setup port forward for a service
# Usage: setup_port_forward "service-name" "namespace" 8081 80
# Args: service_name, namespace, local_port, remote_port
# Returns: PID of port-forward process, or empty string on failure
setup_port_forward() {
  local svc_name=$1
  local ns=$2
  local local_port=$3
  local remote_port=$4
  local pf_pid=""

  print_step "Setting up port-forward on localhost:$local_port..."
  kubectl port-forward "svc/$svc_name" "$local_port:$remote_port" -n "$ns" >/dev/null 2>&1 &
  pf_pid=$!
  PF_PIDS+=("$pf_pid")

  if ! wait_for_port_forward "$local_port"; then
    print_error_indent "Port-forward failed to establish"
    kill "$pf_pid" 2>/dev/null || true
    return 1
  fi

  echo "$pf_pid"
  return 0
}

# Wait for port-forward to be ready
# Usage: wait_for_port_forward 8081 10
# Args: port, max_wait_seconds
# Returns: 0 if ready, 1 if timeout
wait_for_port_forward() {
  local port=$1
  local max_wait=${2:-10}
  local waited=0

  while ! lsof -i:"$port" &>/dev/null && [[ $waited -lt $max_wait ]]; do
    sleep 0.5
    waited=$((waited + 1))
  done

  if [[ $waited -ge $max_wait ]]; then
    return 1
  fi
  return 0
}

# Main function to check if an application is reachable
# Usage: is_app_reachable "service-name" "namespace" "endpoint" local_port remote_port "Label" "expected-string" "hint" ["resource-type" "resource-name" "expected-version"]
# Args: service_name, namespace, endpoint, local_port, remote_port, label, expected_response, hint, [optional: resource_type, resource_name, expected_version]
# Example with version check: is_app_reachable "hotrod" "hotrod" "" 8080 8080 "HotROD" "<title>" "Check the rollout" "rollout" "hotrod" "1.76.0"
is_app_reachable() {
  # args
  local svc=$1
  local ns=$2
  local endpoint=$3
  local local_port=$4
  local remote_port=${5:-80}
  local label=$6
  local expected=$7
  local hint=$8
  local resource_type=${9:-""}
  local resource_name=${10:-""}
  local expected_version=${11:-""}

  local pf_pid=""
  local tmpfile=$(mktemp)
  local failed=0

  print_test_section "Checking $label Environment"

  # Check namespace exists
  if ! namespace_exists "$ns" "$hint"; then
    print_error_indent "Namespace '$ns' does not exist"
    print_hint "$hint"

    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  else
    print_info_indent "✓ Namespace '$ns' exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi

  # Check service exists
  if ! service_exists "$svc" "$ns" "$hint"; then
    print_error_indent "Service "$svc" in '$ns' does not exist"
    print_hint "$hint"

    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  else
    print_info_indent "✓ Service "$svc" in '$ns' exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi

  # Optional: Check resource version if parameters are provided
  if [[ -n "$resource_type" && -n "$resource_name" && -n "$expected_version" ]]; then
    if ! check_resource_version_exists "$resource_type" "$resource_name" "$ns" "$expected_version"; then
      # Get the actual image for error message
      local image
      image=$(kubectl get "$resource_type" "$resource_name" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "not found")

      print_error_indent "$resource_type '$resource_name' in '$ns' does not have version $expected_version (found: $image)"
      print_hint "$hint"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      return
    else
      print_info_indent "✓ $resource_type '$resource_name' has version $expected_version"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  fi

  # Create port forward
  if ! pf_pid=$(setup_port_forward "$svc" "$ns" "$local_port" "$remote_port"); then
    return
  fi

  if ! test_http_endpoint "http://localhost:$local_port/$endpoint" "$expected" "$hint"; then
    return
  fi

  print_new_line
  print_success "✅ $label is healthy!"
}

# Cleanup function to ensure port-forwards are killed
cleanup_port_forwards() {
  local exit_code=$?
  if [[ ${#PF_PIDS[@]} -gt 0 ]]; then
    for pid in "${PF_PIDS[@]}"; do
      kill "$pid" 2>/dev/null || true
    done
  fi
  exit "$exit_code"
}

# Usage: check_resource_version "resource-type" "resource-name" "namespace" "expected-version" "hint"
# Args: resource_type, resource_name, namespace, expected_version, hint
# Example: check_resource_version "rollout" "hotrod" "hotrod" "1.76.0" "Check the rollout manifest"
check_resource_version() {
  local resource_type=$1
  local resource_name=$2
  local ns=$3
  local expected_version=$4
  local hint=$5

  print_test_section "Verifying ${resource_name} version..."

  # Check service exists
  if ! resource_exists "$resource_type" "$resource_name" "$ns" "$hint"; then
    print_error_indent "$resource_type "$resource_name" in '$ns' does not exist"
    print_hint "$hint"

    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Get the image from the resource spec
  local image
  image=$(kubectl get "$resource_type" "$resource_name" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  if [ -z "$image" ]; then
    print_error_indent "$resource_type "$resource_name" in '$ns' has no image configured"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  if [[ "$image" == *"$expected_version"* ]]; then
    print_info_indent "✓ $resource_type $resource_name in $ns has image $image"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    print_error_indent "$resource_type $resource_name in $ns does not have image version $expected_version (found $image)"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Check that a manifest is blocked at admission (dry-run=server expects failure)
# Reads manifest YAML from stdin.
# Usage: check_admission_blocked "display name" "hint" <<EOF ... EOF
check_admission_blocked() {
  local display_name=$1
  local hint=$2

  print_test_section "Checking $display_name is blocked at admission..."

  if kubectl apply --dry-run=server -f - &>/dev/null; then
    print_error_indent "$display_name was admitted — policy not enforcing"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("admission_blocked:$display_name")
  else
    print_success_indent "$display_name was correctly blocked at admission"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

# Check that a manifest is admitted (dry-run=server expects success)
# Reads manifest YAML from stdin.
# Usage: check_admission_allowed "display name" "hint" <<EOF ... EOF
check_admission_allowed() {
  local display_name=$1
  local hint=$2

  print_test_section "Checking $display_name is admitted..."

  if kubectl apply --dry-run=server -f - &>/dev/null; then
    print_success_indent "$display_name was correctly admitted"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name was incorrectly blocked at admission"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("admission_allowed:$display_name")
  fi
}

# Check that a manifest is admitted and has a specific label in the server response.
# Uses server-side dry-run, which triggers mutation webhooks.
# Reads manifest YAML from stdin.
# Usage: check_label_exists "display name" "label-key" "expected-value" "hint" <<EOF ... EOF
check_label_exists() {
  local display_name=$1
  local label_key=$2
  local expected_value=$3
  local hint=$4

  print_test_section "Checking $display_name receives label $label_key=$expected_value via mutation..."

  local result
  if ! result=$(kubectl apply --dry-run=server -f - -o json 2>/dev/null); then
    print_error_indent "$display_name was rejected at admission (expected to be admitted)"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("label_exists:$display_name")
    return
  fi

  local actual_value
  actual_value=$(echo "$result" | jq -r ".metadata.labels[\"$label_key\"] // empty")

  if [[ "$actual_value" == "$expected_value" ]]; then
    print_success_indent "$display_name has label $label_key=$expected_value"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name was admitted but label '$label_key' was not set to '$expected_value' (got: '${actual_value:-<missing>}')"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("label_exists:$display_name")
  fi
}

# Check that a manifest is admitted and does NOT have a specific label in the server response.
# Uses server-side dry-run, which triggers mutation webhooks.
# Reads manifest YAML from stdin.
# Usage: check_label_not_exists "display name" "label-key" "hint" <<EOF ... EOF
check_label_not_exists() {
  local display_name=$1
  local label_key=$2
  local hint=$3

  print_test_section "Checking $display_name does NOT receive label $label_key..."

  local result
  if ! result=$(kubectl apply --dry-run=server -f - -o json 2>/dev/null); then
    print_error_indent "$display_name was rejected at admission (expected to be admitted)"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("label_not_exists:$display_name")
    return
  fi

  local label_value
  label_value=$(echo "$result" | jq -r ".metadata.labels[\"$label_key\"] // empty")

  if [[ -z "$label_value" ]]; then
    print_success_indent "$display_name was admitted without label $label_key (correct)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name was admitted but unexpectedly has label $label_key=$label_value"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("label_not_exists:$display_name")
  fi
}

# Wait for a Deployment to become available, port-forward its Service, and assert
# the HTTP response body contains an expected string. A reusable end-of-pipeline
# "did the workload actually come up and answer" check.
# Usage: check_deployment_serves <name> <namespace> <svc-port> <local-port> <expected> <display> <hint> [timeout_s]
check_deployment_serves() {
  local name=$1 ns=$2 svc_port=$3 local_port=$4 expected=$5 display_name=$6 hint=$7 timeout=${8:-120}

  print_test_section "Checking $display_name..."

  if ! kubectl rollout status "deployment/$name" -n "$ns" --timeout="${timeout}s" >/dev/null 2>&1; then
    print_error_indent "$display_name - deployment/$name never became available in '$ns'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("deployment_unavailable:$name")
    return
  fi

  if ! setup_port_forward "$name" "$ns" "$local_port" "$svc_port" >/dev/null 2>&1; then
    print_error_indent "$display_name - could not port-forward svc/$name in '$ns'"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("port_forward_failed:$name")
    return
  fi

  local body="" tries=0
  while [[ $tries -lt 10 ]]; do
    body=$(curl -s --max-time 5 "http://localhost:$local_port/" 2>/dev/null || echo "")
    [[ "$body" == *"$expected"* ]] && break
    sleep 2
    tries=$((tries + 1))
  done

  if [[ "$body" == *"$expected"* ]]; then
    print_success_indent "$display_name -> $body"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name - unexpected response: ${body:-<empty>}"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("http_unexpected:$name")
  fi
}
