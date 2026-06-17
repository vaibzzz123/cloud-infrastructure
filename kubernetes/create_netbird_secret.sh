#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="$script_dir/04-caddy/.env"
sealedsecret_file="$script_dir/04-caddy/03-sealedsecret.yml"
runtime_env_file="$(mktemp)"

cleanup() {
  rm -f "$runtime_env_file"
}
trap cleanup EXIT

if [[ ! -f "$env_file" ]]; then
  printf 'Missing %s. Create it with NB_CADDY_PROXY_SETUP_KEY=<netbird caddy proxy setup key>.\n' "$env_file" >&2
  exit 1
fi

nb_caddy_proxy_setup_key="$(
  awk -F= '$1 == "NB_CADDY_PROXY_SETUP_KEY" {
    value = substr($0, index($0, "=") + 1)
    gsub(/^"|"$/, "", value)
    print value
    exit
  }' "$env_file"
)"

if [[ -z "$nb_caddy_proxy_setup_key" ]]; then
  printf 'Missing NB_CADDY_PROXY_SETUP_KEY in %s.\n' "$env_file" >&2
  exit 1
fi

awk -F= '$1 != "NB_CADDY_PROXY_SETUP_KEY" && $1 != "NB_SETUP_KEY"' "$env_file" >"$runtime_env_file"
printf 'NB_SETUP_KEY=%s\n' "$nb_caddy_proxy_setup_key" >>"$runtime_env_file"

kubectl create secret generic netbird-secret \
  --namespace caddy \
  --from-env-file="$runtime_env_file" \
  --dry-run=client -o yaml | kubeseal -o yaml >"$sealedsecret_file"
