#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

MIGRATION_DIR="${REPO_ROOT}/kubernetes/migrations/2026-04-15-caddy-namespace-move"
CADDY_DIR="${REPO_ROOT}/kubernetes/caddy"

OLD_NS="default"
NEW_NS="caddy"
DEPLOYMENT="caddy-deployment"
OLD_INGRESS="caddy-ingress"
NEW_TLS_SECRET="vabkapoor-com-tls"
SEALED_SECRET="netbird-secret"
SRC_HELPER="caddy-netbird-copy-src"
DST_HELPER="caddy-netbird-copy-dst"

log() {
  printf '[caddy-migration] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

wait_for_absent_pods() {
  local namespace="$1"
  local selector="$2"
  local timeout="${3:-180}"
  local elapsed=0

  while kubectl -n "${namespace}" get pods -l "${selector}" --no-headers 2>/dev/null | grep -q .; do
    if (( elapsed >= timeout )); then
      printf 'Timed out waiting for pods with selector %s in namespace %s to disappear\n' "${selector}" "${namespace}" >&2
      exit 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
}

wait_for_resource() {
  local namespace="$1"
  local resource="$2"
  local timeout="${3:-180}"
  local elapsed=0

  until kubectl -n "${namespace}" get "${resource}" >/dev/null 2>&1; do
    if (( elapsed >= timeout )); then
      printf 'Timed out waiting for %s in namespace %s\n' "${resource}" "${namespace}" >&2
      exit 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
}

require_cmd kubectl

log "Applying pre-deployment resources in namespace ${NEW_NS}"
kubectl apply -f "${CADDY_DIR}/00-namespace.yml"
kubectl apply -f "${CADDY_DIR}/01-persistentvolumeclaim.yml"
kubectl apply -f "${CADDY_DIR}/02-configmap.yml"
kubectl apply -f "${CADDY_DIR}/03-sealedsecret.yml"

log "Waiting for ${NEW_NS}/${SEALED_SECRET} to exist"
wait_for_resource "${NEW_NS}" "secret/${SEALED_SECRET}" 120

if kubectl -n "${OLD_NS}" get deployment "${DEPLOYMENT}" >/dev/null 2>&1; then
  log "Scaling down ${OLD_NS}/${DEPLOYMENT}"
  kubectl -n "${OLD_NS}" scale deployment "${DEPLOYMENT}" --replicas=0
  wait_for_absent_pods "${OLD_NS}" "app=caddy" 180
else
  log "Old deployment ${OLD_NS}/${DEPLOYMENT} not found, skipping scale-down"
fi

log "Applying helper Pods"
kubectl apply -f "${MIGRATION_DIR}/source-helper.yml"
kubectl apply -f "${MIGRATION_DIR}/destination-helper.yml"

log "Waiting for helper Pods to become Ready"
kubectl -n "${OLD_NS}" wait --for=condition=Ready "pod/${SRC_HELPER}" --timeout=120s
kubectl -n "${NEW_NS}" wait --for=condition=Ready "pod/${DST_HELPER}" --timeout=120s

log "Copying NetBird data from ${OLD_NS} PVC to ${NEW_NS} PVC"
kubectl -n "${OLD_NS}" exec "${SRC_HELPER}" -- sh -c 'cd /data && tar cf - .' \
  | kubectl -n "${NEW_NS}" exec -i "${DST_HELPER}" -- sh -c 'cd /data && tar xpf -'

log "Applying workload resources in namespace ${NEW_NS}"
kubectl apply -f "${CADDY_DIR}/04-deployment.yml"
kubectl apply -f "${CADDY_DIR}/05-service.yml"

log "Waiting for ${NEW_NS}/${DEPLOYMENT} rollout"
kubectl -n "${NEW_NS}" rollout status "deployment/${DEPLOYMENT}" --timeout=180s

log "Switching Ingress from ${OLD_NS} to ${NEW_NS}"
kubectl -n "${OLD_NS}" delete ingress "${OLD_INGRESS}" --ignore-not-found
kubectl apply -f "${CADDY_DIR}/06-ingress.yml"

log "Waiting for ${NEW_NS}/${NEW_TLS_SECRET} to exist"
wait_for_resource "${NEW_NS}" "secret/${NEW_TLS_SECRET}" 300

log "Cutover complete. Verify the caddy namespace, then run 02-cleanup.sh when ready."
