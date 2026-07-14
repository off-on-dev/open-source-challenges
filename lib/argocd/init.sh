#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo " --help             Display this help message"
  echo " --read-only        Disables the ArgoCD admin user and only provides read-only access"
  echo " --version <ver>    Argo CD version to install (required)"
}

# Parse flags
read_only=false
version=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      help
      exit 0
      ;;
    --read-only)
      read_only=true
      shift
      ;;
    --version)
      if [[ -z "${2-}" ]]; then
        echo "Error: --version requires a value" >&2
        exit 1
      fi
      version="$2"
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

echo "✨ Installing Argo CD"
kubectl create namespace argocd

manifests_tmp="$(mktemp -d)"
trap 'rm -rf "${manifests_tmp}"' EXIT
cp -r "$SCRIPT_DIR/manifests/." "${manifests_tmp}/"
sed -i "s|argoproj/argo-cd/[^/]*/manifests/install.yaml|argoproj/argo-cd/${version}/manifests/install.yaml|" \
  "${manifests_tmp}/kustomization.yaml"
# Server-side apply: recent Argo CD CRDs (applications/applicationsets) are
# large enough that client-side apply's kubectl.kubernetes.io/last-applied-configuration
# annotation pushes metadata.annotations past Kubernetes' 256KiB limit. This is
# a known Argo CD issue; --server-side avoids the annotation entirely instead
# of shrinking under it. See https://argo-cd.readthedocs.io/en/latest/operator-manual/upgrading/3.2-3.3/
kubectl apply -k "${manifests_tmp}" --server-side --force-conflicts

echo "✨ Installing Argo CD CLI"
# shellcheck disable=SC1091
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../scripts/arch.sh"
curl -sSL -o "argocd-linux-${ARCH}" "https://github.com/argoproj/argo-cd/releases/download/${version}/argocd-linux-${ARCH}"
sudo install -m 555 "argocd-linux-${ARCH}" /usr/local/bin/argocd
rm "argocd-linux-${ARCH}"

echo "✨ Waiting for Argo CD server to be ready"
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
sleep 3 # Give Argo CD a moment to be ready after restart


if [ "$read_only" = true ]; then
  echo "✨ Setting password for user readonly"
  admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  argocd login localhost:30100 --username admin --password "$admin_password" --plaintext
  argocd account update-password \
    --account readonly \
    --current-password "$admin_password" \
    --new-password a-super-secure-password

  echo "✨ Disabling admin user for read-only mode"
  kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"accounts.admin.enabled":"false"}}'
  kubectl -n argocd delete secret argocd-initial-admin-secret

  echo "✨ Restarting Argo CD server"
  kubectl -n argocd rollout restart deployment/argocd-server
  kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
  sleep 3 # Give Argo CD a moment to be ready after restart

  echo "✨ Logging in as readonly user"
  argocd login localhost:30100 --username readonly --password a-super-secure-password --plaintext
fi

echo "✅ Argo CD is ready"
