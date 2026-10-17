#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_dir="$repo_root/terraform"
output_file="${TERRAFORM_OUTPUT_FILE:-$repo_root/.local/terraform-outputs.env}"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

quote_env() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

derive_private_key_path() {
  local public_key_path="$1"
  printf '%s\n' "${public_key_path%.pub}"
}

require terraform
require jq

if [[ ! -f "$terraform_dir/terraform.tfvars" ]]; then
  printf 'Missing %s. Create it from terraform.tfvars.example first.\n' "$terraform_dir/terraform.tfvars" >&2
  exit 1
fi

terraform -chdir="$terraform_dir" init
terraform -chdir="$terraform_dir" apply

outputs="$(terraform -chdir="$terraform_dir" output -json)"
mkdir -p "$(dirname "$output_file")"

public_key_path="$(terraform -chdir="$terraform_dir" console <<<"var.ssh_public_key_path" | tr -d '"')"
uptime_monitor_public_key_path="$(terraform -chdir="$terraform_dir" console <<<"var.uptime_monitor_ssh_public_key_path" | tr -d '"')"
server_public_ip="$(jq -r '.k3s_server_public_ip.value' <<<"$outputs")"
server_private_ip="$(jq -r '.k3s_server_private_ip.value' <<<"$outputs")"
uptime_monitor_public_ip="$(jq -r '.uptime_monitor_public_ip.value' <<<"$outputs")"
uptime_monitor_private_ip="$(jq -r '.uptime_monitor_private_ip.value' <<<"$outputs")"
ssh_private_key_path="$(derive_private_key_path "$public_key_path")"
uptime_monitor_ssh_private_key_path="$(derive_private_key_path "$uptime_monitor_public_key_path")"
agent_count="$(jq -r '.k3s_agent_public_ips.value | length' <<<"$outputs")"

{
  printf 'K3S_SERVER_PUBLIC_IP=%s\n' "$(quote_env "$server_public_ip")"
  printf 'K3S_SERVER_PRIVATE_IP=%s\n' "$(quote_env "$server_private_ip")"
  printf 'K3S_AGENT_COUNT=%s\n' "$(quote_env "$agent_count")"
  printf 'SSH_PRIVATE_KEY_PATH=%s\n' "$(quote_env "$ssh_private_key_path")"
  printf 'UPTIME_MONITOR_PUBLIC_IP=%s\n' "$(quote_env "$uptime_monitor_public_ip")"
  printf 'UPTIME_MONITOR_PRIVATE_IP=%s\n' "$(quote_env "$uptime_monitor_private_ip")"
  printf 'UPTIME_MONITOR_SSH_PRIVATE_KEY_PATH=%s\n' "$(quote_env "$uptime_monitor_ssh_private_key_path")"


  for ((i = 0; i < agent_count; i++)); do
    agent_number="$((i + 1))"
    agent_public_ip="$(jq -r ".k3s_agent_public_ips.value[$i]" <<<"$outputs")"
    agent_private_ip="$(jq -r ".k3s_agent_private_ips.value[$i]" <<<"$outputs")"
    printf 'K3S_AGENT_%s_PUBLIC_IP=%s\n' "$agent_number" "$(quote_env "$agent_public_ip")"
    printf 'K3S_AGENT_%s_PRIVATE_IP=%s\n' "$agent_number" "$(quote_env "$agent_private_ip")"
  done
} >"$output_file"

chmod 600 "$output_file"
printf 'Wrote %s\n' "$output_file"
