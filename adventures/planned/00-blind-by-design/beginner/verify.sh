#!/usr/bin/env bash
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../../../lib/scripts/loader.sh"

OBJECTIVE="By the end of this level, you should:

- See curl http://localhost:8080/ return a vision_state reading resolved from flags.json (not the hard-coded fallback)
- Confirm the response payload includes the OpenFeature evaluation details (variant, reason, value)
- Edit flags.json to change the defaultVariant, save, and have the next request return the new variant without restarting the app"

DOCS_URL="https://dynatrace-oss.github.io/open-ecosystem-challenges/00-blind-by-design/beginner"

APP_URL="http://localhost:8080/"
FLAGS_FILE="$SCRIPT_DIR/flags.json"

print_header \
  'Adventure 00: Blind by Design' \
  'Level 1: Stand up the lab' \
  'Smoke Test Verification'

check_prerequisites curl jq

print_sub_header "Running smoke tests..."

# Track test results across all checks
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_CHECKS=()

# 1. The Spring Boot lab is reachable on :8080.
print_test_section "Checking the lab is reachable on $APP_URL..."
RESPONSE=$(curl -sS --max-time 5 "$APP_URL" 2>/dev/null || echo "")

if [[ -z "$RESPONSE" ]]; then
  print_error_indent "Lab did not respond on $APP_URL"
  print_hint "Start the app with: ./mvnw spring-boot:run"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("lab_unreachable")
  print_test_summary "stand up the lab" "$DOCS_URL" "$OBJECTIVE"
  exit
fi
print_success_indent "Lab responded on $APP_URL"
TESTS_PASSED=$((TESTS_PASSED + 1))

# 2. Response is FlagEvaluationDetails JSON containing flag_key="vision_state".
print_test_section "Checking the response is an OpenFeature evaluation for 'vision_state'..."
FLAG_KEY=$(echo "$RESPONSE" | jq -r '.flagKey // .flag_key // empty' 2>/dev/null || echo "")

if [[ "$FLAG_KEY" != "vision_state" ]]; then
  print_error_indent "Response did not include 'flagKey':'vision_state'"
  print_info_indent "Actual response: $RESPONSE"
  print_hint "Wire client.getStringDetails(\"vision_state\", ...) in Trial and return the FlagEvaluationDetails."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("flag_key_missing")
else
  print_success_indent "Response carries OpenFeature evaluation details for 'vision_state'"
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# 3. The resolved value is NOT the literal "untreated" fallback.
print_test_section "Checking the value is resolved from a provider, not the hard-coded fallback..."
VALUE=$(echo "$RESPONSE" | jq -r '.value // empty' 2>/dev/null || echo "")
REASON=$(echo "$RESPONSE" | jq -r '.reason // empty' 2>/dev/null || echo "")

if [[ "$VALUE" == "untreated" ]]; then
  print_error_indent "Value is still the hard-coded fallback 'untreated' (reason=$REASON)"
  print_hint "Configure a FlagdProvider in RPC mode (talks to the flagd sidecar on flagd:8013) and add a 'vision_state' flag to flags.json."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("fallback_value")
elif [[ -z "$VALUE" ]]; then
  print_error_indent "No 'value' field in the response"
  print_info_indent "Actual response: $RESPONSE"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("value_missing")
else
  print_success_indent "Resolved value '$VALUE' (reason=$REASON)"
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# 4. flags.json is hot-reloaded: flip defaultVariant and confirm the response changes.
print_test_section "Checking that flags.json drives the response (hot-reload swap)..."
if [[ ! -f "$FLAGS_FILE" ]]; then
  print_error_indent "flags.json not found at $FLAGS_FILE"
  print_hint "Drop a flags.json next to pom.xml with a 'vision_state' flag (variants: blurry, clouded)."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("flags_json_missing")
else
  ORIGINAL_VARIANT=$(jq -r '.flags.vision_state.defaultVariant // empty' "$FLAGS_FILE")
  if [[ -z "$ORIGINAL_VARIANT" ]]; then
    print_error_indent "Could not read .flags.vision_state.defaultVariant from flags.json"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("flags_json_invalid")
  else
    # Pick a different variant from the file.
    OTHER_VARIANT=$(jq -r --arg cur "$ORIGINAL_VARIANT" '.flags.vision_state.variants | keys[] | select(. != $cur)' "$FLAGS_FILE" | head -n1)
    if [[ -z "$OTHER_VARIANT" ]]; then
      print_error_indent "flags.json only defines a single variant; need at least two for the swap test."
      print_hint "Add a 'clouded' variant alongside 'blurry'."
      TESTS_FAILED=$((TESTS_FAILED + 1))
      FAILED_CHECKS+=("single_variant")
    else
      BACKUP="$(mktemp)"
      cp "$FLAGS_FILE" "$BACKUP"
      # Restore on any exit path.
      trap 'cp "$BACKUP" "$FLAGS_FILE" 2>/dev/null || true; rm -f "$BACKUP"' EXIT

      # Capture the current value, then swap.
      BEFORE_VALUE=$(curl -sS --max-time 5 "$APP_URL" | jq -r '.value // empty')
      jq --arg v "$OTHER_VARIANT" '.flags.vision_state.defaultVariant = $v' "$FLAGS_FILE" > "$FLAGS_FILE.tmp" && mv "$FLAGS_FILE.tmp" "$FLAGS_FILE"

      # Wait up to ~5s for the file watcher to pick up the change.
      AFTER_VALUE="$BEFORE_VALUE"
      for _ in 1 2 3 4 5; do
        sleep 1
        AFTER_VALUE=$(curl -sS --max-time 5 "$APP_URL" | jq -r '.value // empty')
        if [[ "$AFTER_VALUE" != "$BEFORE_VALUE" ]]; then
          break
        fi
      done

      # Restore.
      cp "$BACKUP" "$FLAGS_FILE"
      rm -f "$BACKUP"
      trap - EXIT

      if [[ "$AFTER_VALUE" != "$BEFORE_VALUE" && -n "$AFTER_VALUE" ]]; then
        print_success_indent "Hot-reload works: response changed from '$BEFORE_VALUE' to '$AFTER_VALUE' after editing flags.json"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        print_error_indent "Editing flags.json did not change the response (still '$AFTER_VALUE')"
        print_hint "flagd's file watcher should pick up the edit. Confirm flagd is running (docker compose ps) and that flags.json sits where the compose file mounts it."
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_CHECKS+=("hot_reload_failed")
      fi
    fi
  fi
fi

print_test_summary "stand up the lab" "$DOCS_URL" "$OBJECTIVE"
