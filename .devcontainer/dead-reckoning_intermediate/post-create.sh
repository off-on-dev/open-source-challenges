#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHALLENGE_DIR="$REPO_ROOT/adventures/dead-reckoning/intermediate"

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "dead-reckoning" "intermediate" "06" "07" "2026"
track_container_created

"$REPO_ROOT/lib/shared/init.sh" --version v0.17.0

"$REPO_ROOT/lib/github-cli/init.sh" --version v2.96.0 # https://github.com/cli/cli/releases

"$REPO_ROOT/lib/kubernetes/init.sh" \
  --kind-version v0.32.0 \
  --kubectl-version v1.36.2 \
  --kubens-version v0.11.0 \
  --k9s-version v0.51.0 \
  --helm-version v4.2.3

"$REPO_ROOT/lib/gitea/init.sh" --version 12.6.0

"$REPO_ROOT/lib/argo-workflows/init.sh" --version 1.0.19 # https://artifacthub.io/packages/helm/argo/argo-workflows (app v4.0.7)

"$REPO_ROOT/lib/argo-events/init.sh" --version 2.4.22 # https://artifacthub.io/packages/helm/argo/argo-events (app v1.9.10)

"$REPO_ROOT/lib/argocd/init.sh" --read-only --version v3.4.5 # https://github.com/argoproj/argo-cd/releases

# Create the Gitea organization that vessel repositories are published into.
# The scaffolder's publish:gitea action can only create repos under an existing
# organization, so this must exist before the commissioning template runs.
echo "✨ Creating Gitea organization 'fleet'"
GITEA_URL="http://localhost:30112"
until curl -sf "$GITEA_URL/api/v1/version" >/dev/null 2>&1; do sleep 3; done
# Idempotent: a re-run returns 422 (org already exists), which we ignore.
curl -sf -X POST "$GITEA_URL/api/v1/orgs" \
  -H "Content-Type: application/json" \
  -u "admin:a-super-secure-password" \
  -d '{"username": "fleet", "visibility": "public"}' >/dev/null || true

# Kaniko needs registry credentials to push built images to Gitea's built-in
# container registry, which authenticates with the same admin credentials as
# the Gitea API.
echo "✨ Creating kaniko registry credentials secret"
docker_config_json=$(printf '{"auths":{"localhost:30112":{"auth":"%s"}}}' \
  "$(printf 'admin:a-super-secure-password' | base64 | tr -d '\n')")
kubectl create secret generic kaniko-docker-config \
  --namespace argo-workflows \
  --from-literal=config.json="$docker_config_json" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✨ Installing Backstage dependencies"
# Disable corepack's interactive "download Yarn x.y.z?" prompt. Without this the
# first yarn invocation blocks post-create waiting for stdin that never comes.
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
corepack enable
(cd "$CHALLENGE_DIR/backstage" && yarn install --immutable)

echo "✅ Post-create complete"
