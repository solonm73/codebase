#!/usr/bin/env bash
#
# setup.sh — single entry point for deploying a fork of `codebase` to k8s.
#
# This script is repo-agnostic: the YAML manifests stay identical across
# forks. Only environment variables below change per-fork.
#
# Usage:
#   export IMAGE_OWNER="my-github-org"   # org/user that owns the GH repo
#   export HOSTNAME="app.example.com"    # public hostname for Ingress
#   export NEXTAUTH_SECRET="$(openssl rand -base64 32)"
#   ./k8s/setup.sh apply
#
# Or one-liner:
#   IMAGE_OWNER=my-org HOSTNAME=app.example.com \
#     NEXTAUTH_SECRET=$(openssl rand -base64 32) \
#     ./k8s/setup.sh apply
#
# Commands:
#   init     — generate secret.yaml from secret.yaml.example
#   apply    — render manifests and apply to current kubectl context
#   render   — print rendered YAML to stdout (no apply)
#   delete   — remove all resources from the cluster
#   help     — show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---- defaults ----
IMAGE_OWNER="${IMAGE_OWNER:-your-org}"
HOSTNAME="${HOSTNAME:-}"
NAMESPACE="${NAMESPACE:-codebase}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# ---- helpers ----
log()  { printf '\033[1;34m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed"
}

validate_env() {
    if [[ -z "${NEXTAUTH_SECRET:-}" ]]; then
        warn "NEXTAUTH_SECRET is not set; using placeholder in secret.yaml (app will fail to start)"
    fi
    if [[ -z "$HOSTNAME" ]]; then
        warn "HOSTNAME is not set; Ingress will match all hosts (only works if your cluster has a default backend)"
    fi
}

# ---- commands ----

cmd_init() {
    require_cmd openssl
    if [[ -f "$SCRIPT_DIR/secret.yaml" ]]; then
        die "secret.yaml already exists — delete it first if you want to regenerate"
    fi

    log "Generating secret.yaml from secret.yaml.example..."
    cp secret.yaml.example secret.yaml

    local secret="${NEXTAUTH_SECRET:-$(openssl rand -base64 32)}"
    sed -i "s|REPLACE_ME_WITH_OPENSSL_RAND_BASE64_32|$secret|" secret.yaml

    if [[ -n "$HOSTNAME" ]]; then
        sed -i "s|REPLACE_ME_WITH_PUBLIC_HOSTNAME|$HOSTNAME|" secret.yaml
    fi

    log "secret.yaml created with NEXTAUTH_SECRET and (if set) NEXTAUTH_URL"
    log "edit it if you need OAuth provider credentials, then re-run setup.sh apply"
}

cmd_render() {
    require_cmd kubectl

    log "Rendering manifests..."
    log "  IMAGE_OWNER=$IMAGE_OWNER"
    log "  IMAGE_TAG=$IMAGE_TAG"
    log "  HOSTNAME=${HOSTNAME:-<unset, will match all>}"
    log "  NAMESPACE=$NAMESPACE"

    validate_env
    kustomize_image_rewrite
}

cmd_apply() {
    require_cmd kubectl

    validate_env

    if [[ ! -f "$SCRIPT_DIR/secret.yaml" ]]; then
        warn "secret.yaml not found — running 'init' first"
        cmd_init
    fi

    # Apply secret first (kustomization does not include it by design).
    log "Applying secret..."
    kubectl apply -f secret.yaml

    # Apply the kustomized base. IMAGE_OWNER rewrites the image field on
    # every container that matches the original `name:`.
    log "Applying kustomized manifests to namespace '$NAMESPACE'..."
    kustomize_image_rewrite | kubectl apply -n "$NAMESPACE" -f -

    log "Done. Check status:"
    log "  kubectl -n $NAMESPACE get pods,svc,ingress"
}

# Fallback for Kustomize v4 (K8s ≤ 1.20) — rewrites the image using sed after
# kustomize build. We detect this by trying the build and looking for the
# literal "$(IMAGE_OWNER)" string in output.
kustomize_image_rewrite() {
    local rendered
    rendered=$(IMAGE_OWNER="$IMAGE_OWNER" IMAGE_TAG="$IMAGE_TAG" \
        kustomize build --load-restrictor LoadRestrictionsNone .)

    if grep -q '$(IMAGE_OWNER)' <<<"$rendered"; then
        warn "kustomize did not resolve \$(IMAGE_OWNER) — falling back to sed rewrite"
        rendered=$(sed "s|ghcr.io/your-org/codebase:latest|ghcr.io/$IMAGE_OWNER/codebase:$IMAGE_TAG|g" <<<"$rendered")
    fi

    echo "$rendered"
}

cmd_delete() {
    require_cmd kubectl
    log "Deleting all resources from namespace '$NAMESPACE'..."
    kubectl delete -n "$NAMESPACE" -f secret.yaml --ignore-not-found
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
}

cmd_help() {
    sed -n '2,/^$/p' "$SCRIPT_DIR/setup.sh" | sed 's/^# \{0,1\}//'
}

# ---- entrypoint ----
cmd="${1:-help}"
shift || true

case "$cmd" in
    init)   cmd_init "$@" ;;
    render) cmd_render "$@" ;;
    apply)  cmd_apply "$@" ;;
    delete) cmd_delete "$@" ;;
    help|-h|--help) cmd_help ;;
    *) die "Unknown command: $cmd. Run './setup.sh help'." ;;
esac
