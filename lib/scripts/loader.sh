#!/usr/bin/env bash

# loader.sh - Main library loader
# This script loads all shared libraries for smoke test scripts
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/../lib/scripts/loader.sh"

# Get the directory where this script is located
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library files
# shellcheck disable=SC1091
source "$LIB_DIR/output.sh"
source "$LIB_DIR/prerequisites.sh"
source "$LIB_DIR/http.sh"
source "$LIB_DIR/filesystem.sh"
source "$LIB_DIR/kubernetes.sh"
source "$LIB_DIR/kyverno.sh"
source "$LIB_DIR/prometheus.sh"
source "$LIB_DIR/argo-rollouts.sh"
source "$LIB_DIR/gcp-mock.sh"
source "$LIB_DIR/github.sh"
source "$LIB_DIR/gitea.sh"
source "$LIB_DIR/backstage.sh"
source "$LIB_DIR/submission.sh"
source "$LIB_DIR/tracker.sh"
source "$LIB_DIR/jaeger.sh"
source "$LIB_DIR/falco.sh"

# Set up cleanup trap for port-forwards
trap cleanup_port_forwards EXIT INT TERM
