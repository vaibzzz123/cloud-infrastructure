#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="$script_dir/04-caddy/wg0.conf"
sealedsecret_file="$script_dir/04-caddy/03-sealedsecret.yml"
temporary_sealedsecret_file="$(mktemp "$sealedsecret_file.XXXXXX")"

cleanup() {
  rm -f "$temporary_sealedsecret_file"
}
trap cleanup EXIT

for required_command in kubectl kubeseal; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$required_command" >&2
    exit 1
  fi
done

if [[ ! -s "$config_file" ]]; then
  printf 'Missing or empty WireGuard configuration: %s\n' "$config_file" >&2
  exit 1
fi

kubectl create secret generic wireguard-secret \
  --namespace caddy \
  --from-file=wg0.conf="$config_file" \
  --dry-run=client \
  --output=yaml |
  kubeseal --format=yaml >"$temporary_sealedsecret_file"

mv "$temporary_sealedsecret_file" "$sealedsecret_file"
trap - EXIT

printf 'Wrote %s from %s.\n' "$sealedsecret_file" "$config_file"
