#!/usr/bin/env bash
# tracker.sh - Sends bizevents to the offon-challenge-tracker Cloud Run service

TRACKER_URL="https://offon-challenge-tracker-291758365471.europe-west1.run.app"
EVENT_TYPE="offon.challenge"
SESSION_ID_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.offon-session-id"
# Set OFFON_EXTERNAL_SOURCE to tag events from a repo that copied these challenges
# Left unset here, so this repo's events omit the field.

# -----------------------------------------------------------------------------
# Set tracking context and ensure a session ID exists
# Usage: set_tracking_context "lex-imperfecta" "beginner" "05" "06" "2026"
# -----------------------------------------------------------------------------
set_tracking_context() {
  local adventure=$1
  local level=$2
  local adventure_number=${3:-""}
  local publish_month=${4:-""}
  local publish_year=${5:-""}

  export ADVENTURE="$adventure"
  export LEVEL="$level"
  export ADVENTURE_NUMBER="$adventure_number"
  export PUBLISH_MONTH="$publish_month"
  export PUBLISH_YEAR="$publish_year"

  if [[ ! -f "$SESSION_ID_FILE" ]]; then
    cat /proc/sys/kernel/random/uuid > "$SESSION_ID_FILE"
  fi
  export OFFON_SESSION_ID
  OFFON_SESSION_ID=$(cat "$SESSION_ID_FILE")
}

# -----------------------------------------------------------------------------
# Send an event to the tracker (silent, never fails the caller)
# Usage: send_event "event.action" '{"extra": "fields"}'
# -----------------------------------------------------------------------------
send_event() {
  local action=$1
  local extra_fields=${2:-"{}"}

  local payload
  payload=$(jq -n \
    --arg event_type "$EVENT_TYPE" \
    --arg action "$action" \
    --arg adventure "${ADVENTURE:-unknown}" \
    --arg level "${LEVEL:-unknown}" \
    --arg session_id "${OFFON_SESSION_ID:-unknown}" \
    --arg github_user "${GITHUB_USER:-}" \
    --arg github_repo "${GITHUB_REPOSITORY:-}" \
    --arg adventure_number "${ADVENTURE_NUMBER:-}" \
    --arg publish_month "${PUBLISH_MONTH:-}" \
    --arg publish_year "${PUBLISH_YEAR:-}" \
    --arg external_source "${OFFON_EXTERNAL_SOURCE:-}" \
    --argjson extra "$extra_fields" \
    '{
      "type": $event_type,
      "action": $action,
      "adventure.name": $adventure,
      "adventure.number": $adventure_number,
      "adventure.month": $publish_month,
      "adventure.year": $publish_year,
      "adventure.level": $level,
      "session.id": $session_id,
      "github.username": $github_user,
      "github.repository": $github_repo
    }
    + (if $external_source != "" then {"external.source": $external_source} else {} end)
    + $extra'
  )

  curl -sS -X POST "$TRACKER_URL" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    >/dev/null 2>&1 || true
}

track_container_created() {
  send_event "container.created"
}

track_container_initialized() {
  send_event "container.initialized"
}

track_verification_completed() {
  local status=$1
  local failed_checks=${2:-"[]"}

  send_event "verification.completed" "$(jq -n \
    --arg status "$status" \
    --argjson failed_checks "$failed_checks" \
    '{"verification.status": $status, "verification.failed_checks": $failed_checks}'
  )"
}
