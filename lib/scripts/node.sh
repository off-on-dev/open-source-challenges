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
  else
    print_error_indent "$display_name"
    print_info_indent "expected: $expected"
    print_info_indent "found:    $actual"
    print_hint "$hint"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CHECKS+=("npm_dependencies")
  fi

  print_new_line
}
