#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHALLENGE_DIR="$REPO_ROOT/adventures/dead-reckoning/intermediate"
GITEA_URL="http://localhost:30112"
GITEA_AUTH="admin:a-super-secure-password"

# Bring up the trigger path (Gitea push -> Argo Events -> Argo Workflow) and
# the delivery workflow itself (clone -> build -> update-deploy).
echo "✨ Applying the Argo Events trigger path"
kubectl apply -f "$CHALLENGE_DIR/platform/argo-events/"
echo "✨ Applying the delivery workflow"
kubectl apply -f "$CHALLENGE_DIR/platform/argo-workflows/"
echo "✨ Applying the Argo CD ApplicationSet"
kubectl apply -f "$CHALLENGE_DIR/platform/argocd/"

# The EventSource controller creates gitea-webhook-eventsource-svc once it
# reconciles the EventSource applied above; the org webhook can't be
# registered until that Service (its DNS name is the webhook target) exists.
echo "✨ Waiting for the gitea-webhook EventSource to be ready"
until kubectl get svc gitea-webhook-eventsource-svc -n argo-events >/dev/null 2>&1; do sleep 3; done

echo "✨ Registering the fleet org webhook"
until curl -sf "$GITEA_URL/api/v1/version" >/dev/null 2>&1; do sleep 3; done
# Idempotent: a re-run returns 422 (an identical hook already exists), which
# we ignore. Every repo pushed to the fleet org fires this webhook; the
# Sensor (platform/argo-events/sensor.yaml) is what filters out "-deploy"
# pushes, not the webhook itself.
curl -sf -X POST "$GITEA_URL/api/v1/orgs/fleet/hooks" \
  -H "Content-Type: application/json" \
  -u "$GITEA_AUTH" \
  -d '{
        "type": "gitea",
        "config": {
          "url": "http://gitea-webhook-eventsource-svc.argo-events.svc.cluster.local:12000/push",
          "content_type": "json"
        },
        "events": ["push"],
        "active": true
      }' >/dev/null || true

cat <<'EOF'

✨ Dead Reckoning — 🟡 Intermediate (Sea Trial)

The platform is up:
  • Gitea (the archives)          → port 30112
  • Argo Workflows (the shipyard) → port 30113
  • Argo CD (the harbor master)   → port 30100

▶  Start Backstage (the commission office):
     make backstage

✅ When you think you've fixed the pipeline, verify your work:
     make verify

EOF

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "dead-reckoning" "intermediate" "06" "07" "2026"
track_container_initialized