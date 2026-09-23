#!/usr/bin/env bash

# node.sh - Helper functions for challenges built as Node projects
# These functions verify JavaScript project state and browser-driven tests

# -----------------------------------------------------------------------------
# Run the Playwright tests carrying a tag and report them as one check
# Usage: check_playwright_tests "@tag" "Display Name" "Hint message" [project_dir]
# -----------------------------------------------------------------------------
check_playwright_tests() {
  local tag=$1
  local display_name=$2
  local hint=$3
  local project_dir=${4:-.}

  print_test_section "Checking $display_name..."

  if (cd "$project_dir" && npx playwright test --grep "$tag" --reporter=list); then
    print_success_indent "$display_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error_indent "$display_name"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("playwright:${tag#@}")
  fi

  print_new_line
}

# -----------------------------------------------------------------------------
# Run the Playwright tests carrying a tag and require them to FAIL.
#
# A suite that passes only proves it ran, not that it looked anywhere useful.
# Inject a fault the suite ought to catch, call this, and a green result means
# the fault went unseen. Test output is suppressed: here a failing run is the
# success case, and printing red output would read as a broken challenge.
#
# Usage: check_playwright_tests_detect "@tag" "Display Name" "Hint message" [project_dir]
# -----------------------------------------------------------------------------
check_playwright_tests_detect() {
  local tag=$1
  local display_name=$2
  local hint=$3
  local project_dir=${4:-.}
  local status=0

  print_test_section "Checking ${display_name}..."

  (cd "${project_dir}" && npx playwright test --grep "${tag}" --reporter=line >/dev/null 2>&1) || status=$?

  # Playwright exits 1 when tests fail, which is the outcome this check wants.
  # Anything else — no tests matched, a crash, a signal (130 for Ctrl-C) — says
  # nothing about whether the fault was caught, so it must not read as success.
  if [[ ${status} -eq 1 ]]; then
    print_success_indent "${display_name}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  elif [[ ${status} -eq 0 ]]; then
    print_error_indent "${display_name}"
    print_hint "${hint}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("playwright_detect:${tag#@}")
  else
    print_error_indent "${display_name}"
    print_hint "The test run ended with exit code ${status} rather than a test failure, so this check could not be measured. Run 'npx playwright test --grep \"${tag}\"' to see what happened."
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("playwright_detect_error:${tag#@}")
  fi

  print_new_line
}

# -----------------------------------------------------------------------------
# Check a package.json declares exactly the expected set of dependency names
# Usage: check_npm_dependencies "package.json" "expected names, space separated" "Display Name" "Hint message"
# -----------------------------------------------------------------------------
check_npm_dependencies() {
  local manifest=$1
  local expected=$2
  local display_name=$3
  local hint=$4

  print_test_section "Checking $display_name..."

  local actual
  actual=$(jq -r '
    [(.dependencies // {}), (.devDependencies // {})]
    | add
    | keys_unsorted
    | sort
    | join(" ")
  ' "$manifest" 2>/dev/null)

  if [[ "$actual" == "$expected" ]]; then
    print_success_indent "$display_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    print_new_line
    return
  fi

  print_error_indent "$display_name"

  # Report the difference rather than the whole list, so the message is about
  # what the player actually did.
  local added removed
  added=$(comm -13 <(tr ' ' '\n' <<<"$expected" | sort) <(tr ' ' '\n' <<<"$actual" | sort) | tr '\n' ' ')
  removed=$(comm -23 <(tr ' ' '\n' <<<"$expected" | sort) <(tr ' ' '\n' <<<"$actual" | sort) | tr '\n' ' ')

  [[ -n "${added// }" ]] && print_info_indent "added:   ${added% }"
  [[ -n "${removed// }" ]] && print_info_indent "removed: ${removed% }"

  print_hint "$hint"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_CHECKS+=("npm_dependencies")

  print_new_line
}
