#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo " --help                Display this help message"
  echo " --version <ver>       Argo Workflows Helm chart version to install (required)"
  echo " --no-wait             Skip waiting for Argo Workflows to be ready"
  echo " --timeout <duration>  Timeout for wait operations (default: 5m)"
}

# Parse flags
version=""
no_wait=false
timeout="5m"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      help
      exit 0
      ;;
    --version)
      if [[ -z "${2-}" ]]; then
        echo "Error: --version requires a value" >&2
        exit 1
      fi
      version="$2"
      shift 2
      ;;
    --no-wait)
      no_wait=true
      shift
      ;;
    --timeout)
      if [[ -z "${2-}" ]]; then
        echo "Error: --timeout requires a value" >&2
        exit 1
      fi
      timeout="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$version" ]]; then
  echo "Error: --version is required" >&2
  exit 1
fi

echo "✨ Adding Argo Helm repo"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "✨ Creating argo-workflows namespace"
kubectl create namespace argo-workflows

echo "✨ Installing Argo Workflows via Helm"
helm_args=(
  --version "$version"
  --namespace argo-workflows
  --values "$SCRIPT_DIR/values.yaml"
)
if [[ "$no_wait" == false ]]; then
  helm_args+=(--wait --timeout "$timeout")
fi
helm install argo-workflows argo/argo-workflows "${helm_args[@]}"

echo "✅ Argo Workflows is ready"
