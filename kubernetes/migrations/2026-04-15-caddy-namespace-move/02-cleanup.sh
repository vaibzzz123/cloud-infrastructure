#!/usr/bin/env bash

set -euo pipefail

OLD_NS="default"
NEW_NS="caddy"
SRC_HELPER="caddy-netbird-copy-src"
DST_HELPER="caddy-netbird-copy-dst"

log() {
  printf '[caddy-migration] %s\n' "$*"
}

if ! command -v kubectl >/dev/null 2>&1; then
  printf 'Missing required command: kubectl\n' >&2
  exit 1
fi

log "Deleting helper Pods"
kubectl -n "${OLD_NS}" delete pod "${SRC_HELPER}" --ignore-not-found
kubectl -n "${NEW_NS}" delete pod "${DST_HELPER}" --ignore-not-found

log "Deleting old default namespace Caddy resources"
kubectl -n "${OLD_NS}" delete ingress caddy-ingress --ignore-not-found
kubectl -n "${OLD_NS}" delete service caddy-service --ignore-not-found
kubectl -n "${OLD_NS}" delete configmap caddy-configmap --ignore-not-found
kubectl -n "${OLD_NS}" delete sealedsecret netbird-secret --ignore-not-found
kubectl -n "${OLD_NS}" delete deployment caddy-deployment --ignore-not-found

log "Leaving ${OLD_NS}/netbird-pvc in place for rollback insurance"
