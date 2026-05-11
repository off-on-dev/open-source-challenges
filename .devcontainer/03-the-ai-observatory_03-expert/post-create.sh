#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Fork the repo into the user's account if running inside a Codespace.
if [[ "${CODESPACES:-}" == "true" ]]; then
  gh repo fork --clone=false --remote=false || true
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/scripts/tracker.sh"
set_tracking_context "03-the-ai-observatory" "expert"
track_codespace_created

"$REPO_ROOT/lib/shared/init.sh" --version v0.17.0 # https://github.com/charmbracelet/gum/releases
# kind: https://github.com/kubernetes-sigs/kind/releases | kubectl: https://dl.k8s.io | kubens: https://github.com/ahmetb/kubectx/releases | k9s: https://github.com/derailed/k9s/releases | helm: https://github.com/helm/helm/releases
"$REPO_ROOT/lib/kubernetes/init.sh" \
  --kind-version v0.30.0 \
  --kubectl-version v1.34.1 \
  --kubens-version v0.9.5 \
  --k9s-version v0.50.16 \
  --helm-version v4.0.1
"$REPO_ROOT/lib/jaeger/init.sh" --version 4.1.5 # https://artifacthub.io/packages/helm/jaegertracing/jaeger
"$REPO_ROOT/lib/otel-collector/init.sh" --version 0.148.0 # https://github.com/open-telemetry/opentelemetry-collector-releases/releases
"$REPO_ROOT/lib/ollama/init.sh" --version 1.40.0 # https://artifacthub.io/packages/helm/otwld/ollama
"$REPO_ROOT/lib/qdrant/init.sh" --version 1.16.3 # https://artifacthub.io/packages/helm/qdrant/qdrant
