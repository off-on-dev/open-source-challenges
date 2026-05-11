#!/usr/bin/env bash
set -e

# Fork the repo into the user's account if running inside a Codespace.
if [[ "${CODESPACES:-}" == "true" ]]; then
  gh repo fork --clone=false --remote=false || true
fi

lib/shared/init.sh --version v0.17.0 # https://github.com/charmbracelet/gum/releases
# kind: https://github.com/kubernetes-sigs/kind/releases | kubectl: https://dl.k8s.io | kubens: https://github.com/ahmetb/kubectx/releases | k9s: https://github.com/derailed/k9s/releases | helm: https://github.com/helm/helm/releases
lib/kubernetes/init.sh \
  --kind-version v0.30.0 \
  --kubectl-version v1.34.1 \
  --kubens-version v0.9.5 \
  --k9s-version v0.50.16 \
  --helm-version v4.0.1
lib/argocd/init.sh --read-only --version v3.2.0 # https://github.com/argoproj/argo-cd/releases
lib/argo-rollouts/init.sh --version v1.8.3 # https://github.com/argoproj/argo-rollouts/releases
lib/kube-state-metrics/init.sh --version 7.0.0 # https://artifacthub.io/packages/helm/prometheus-community/kube-state-metrics
lib/prometheus/init.sh --version 29.1.0 # https://artifacthub.io/packages/helm/prometheus-community/prometheus