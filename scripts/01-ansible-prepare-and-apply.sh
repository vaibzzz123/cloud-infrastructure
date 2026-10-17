#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ansible_dir="$repo_root/ansible"
terraform_dir="$repo_root/terraform"
group_vars_dir="$ansible_dir/group_vars"
input_file="${TERRAFORM_OUTPUT_FILE:-$repo_root/.local/terraform-outputs.env}"
vault_password_file="$group_vars_dir/.vault_password"
ansible_user="${ANSIBLE_USER:-ubuntu}"
all_dir="$group_vars_dir/all"
all_file="$all_dir/main.yml"
server_file="$group_vars_dir/server.yml"
agent_file="$group_vars_dir/agent.yml"
uptime_monitor_file="$group_vars_dir/uptime_monitor.yml"
secrets_file="$all_dir/secrets.yml"
trusted_cidrs=()

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

confirm() {
  local prompt="$1"
  local answer

  printf '%s [y/N]: ' "$prompt"
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

secret_var_is_set() {
  local var_name="$1"

  [[ -f "$secrets_file" ]] && grep -Eq "^${var_name}: *\"?[^\"]+\"? *$" "$secrets_file"
}

read_existing_secret_var() {
  local var_name="$1"

  awk -F': *' -v key="$var_name" '$1 == key { value = $2; gsub(/^"|"$/, "", value); print value; exit }' "$secrets_file"
}

trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_required_secret() {
  local prompt="$1"
  local value

  while true; do
    printf '%s: ' "$prompt" >&2
    read -rs value
    printf '\n' >&2

    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi

    printf 'Value cannot be empty.\n' >&2
  done
}

is_encrypted() {
  [[ -f "$1" ]] && head -n 1 "$1" | grep -q '^\$ANSIBLE_VAULT;'
}

write_vault_password_file() {
  local password password_confirm

  if [[ -f "$vault_password_file" ]]; then
    return 0
  fi

  printf 'No %s found.\n' "$vault_password_file"
  while true; do
    printf 'Enter a new Ansible vault password: '
    read -rs password
    printf '\nConfirm the new Ansible vault password: '
    read -rs password_confirm
    printf '\n'

    if [[ -z "$password" ]]; then
      printf 'Password cannot be empty.\n' >&2
    elif [[ "$password" != "$password_confirm" ]]; then
      printf 'Passwords did not match.\n' >&2
    else
      break
    fi
  done

  umask 077
  printf '%s\n' "$password" >"$vault_password_file"
  printf 'Created %s\n' "$vault_password_file"
}

decrypt_group_vars_if_needed() {
  if is_encrypted "$all_file" || is_encrypted "$server_file" || is_encrypted "$agent_file" || is_encrypted "$uptime_monitor_file"; then
    (cd "$ansible_dir" && ./decrypt.sh)
  fi
}

encrypt_group_vars() {
  (cd "$ansible_dir" && ./encrypt.sh)
}

install_ansible_requirements() {
  (cd "$ansible_dir" && ansible-galaxy collection install -r requirements.yml)
}

read_trusted_cidrs_from_terraform() {
  if ! command -v terraform >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  terraform -chdir="$terraform_dir" output -json trusted_cidrs 2>/dev/null \
    | jq -er '.[]'
}

parse_comma_separated_cidrs() {
  local input="$1"
  local cidr
  local parts=()

  IFS=',' read -r -a parts <<<"$input"
  for cidr in "${parts[@]}"; do
    cidr="$(trim "$cidr")"
    if [[ -n "$cidr" ]]; then
      printf '%s\n' "$cidr"
    fi
  done
}

cidrs_look_valid() {
  local cidr

  if (($# == 0)); then
    return 1
  fi

  for cidr in "$@"; do
    if [[ ! "$cidr" =~ ^[0-9A-Fa-f:.]+/[0-9]{1,3}$ ]]; then
      return 1
    fi
  done
}

prompt_for_trusted_cidrs() {
  local input
  local parsed_cidrs=()

  while true; do
    printf 'Enter k3s API trusted CIDRs as a comma-separated list: '
    read -r input
    mapfile -t parsed_cidrs < <(parse_comma_separated_cidrs "$input")

    if cidrs_look_valid "${parsed_cidrs[@]}"; then
      trusted_cidrs=("${parsed_cidrs[@]}")
      return 0
    fi

    printf 'Enter at least one CIDR, for example: 203.0.113.10/32, 198.51.100.0/24\n' >&2
  done
}

select_trusted_cidrs() {
  local terraform_cidrs
  local parsed_cidrs=()

  terraform_cidrs="$(read_trusted_cidrs_from_terraform || true)"
  if [[ -n "$terraform_cidrs" ]]; then
    mapfile -t parsed_cidrs <<<"$terraform_cidrs"

    printf '\nTerraform trusted_cidrs output:\n'
    printf '  - %s\n' "${parsed_cidrs[@]}"

    if confirm "Use these CIDRs for k3s_api_trusted_cidrs in $secrets_file?"; then
      trusted_cidrs=("${parsed_cidrs[@]}")
      return 0
    fi
  else
    printf '\nCould not read Terraform trusted_cidrs output. Falling back to manual entry.\n' >&2
  fi

  prompt_for_trusted_cidrs
}

remove_secret_key_block() {
  local key="$1"
  local tmp_file

  if [[ ! -f "$secrets_file" ]]; then
    return 0
  fi

  tmp_file="$(mktemp)"
  awk -v key="$key" '
    $0 ~ "^" key ":" {
      skipping = 1
      next
    }
    skipping && $0 ~ /^[^[:space:]#][^:]*:/ {
      skipping = 0
    }
    !skipping {
      print
    }
  ' "$secrets_file" >"$tmp_file"
  mv "$tmp_file" "$secrets_file"
}

append_trusted_cidrs_to_secrets() {
  local cidr

  remove_secret_key_block k3s_api_trusted_cidrs

  if [[ -s "$secrets_file" ]]; then
    printf '\n' >>"$secrets_file"
  fi

  printf 'k3s_api_trusted_cidrs:\n' >>"$secrets_file"
  for cidr in "${trusted_cidrs[@]}"; do
    printf '  - "%s"\n' "$cidr" >>"$secrets_file"
  done
  chmod 600 "$secrets_file"
}

ensure_netbird_setup_keys() {
  local setup_key

  if ! secret_var_is_set netbird_k3s_nodes_setup_key; then
    setup_key="$(read_required_secret 'Enter NetBird k3s nodes setup key')"
    printf 'netbird_k3s_nodes_setup_key: "%s"\n' "$setup_key" >>"$secrets_file"
    printf 'Added netbird_k3s_nodes_setup_key to %s\n' "$secrets_file"
  fi

  if ! secret_var_is_set netbird_uptime_monitor_setup_key; then
    setup_key="$(read_required_secret 'Enter NetBird uptime monitor setup key')"
    printf 'netbird_uptime_monitor_setup_key: "%s"\n' "$setup_key" >>"$secrets_file"
    printf 'Added netbird_uptime_monitor_setup_key to %s\n' "$secrets_file"
  fi
}

write_cluster_secrets_if_needed() {
  local k3s_token netbird_k3s_nodes_setup_key netbird_uptime_monitor_setup_key

  if is_encrypted "$secrets_file"; then
    printf '%s is encrypted. Decrypt it before updating cluster secrets.\n' "$secrets_file" >&2
    exit 1
  fi

  select_trusted_cidrs

  if [[ -f "$secrets_file" ]]; then
    chmod 600 "$secrets_file"

    if ! confirm "$secrets_file already exists. Regenerate k3s_token?"; then
      ensure_netbird_setup_keys
      append_trusted_cidrs_to_secrets
      printf 'Updated k3s_api_trusted_cidrs in %s\n' "$secrets_file"
      return 0
    fi

    ensure_netbird_setup_keys
    netbird_k3s_nodes_setup_key="$(read_existing_secret_var netbird_k3s_nodes_setup_key)"
    netbird_uptime_monitor_setup_key="$(read_existing_secret_var netbird_uptime_monitor_setup_key)"
  else
    netbird_k3s_nodes_setup_key="$(read_required_secret 'Enter NetBird k3s nodes setup key')"
    netbird_uptime_monitor_setup_key="$(read_required_secret 'Enter NetBird uptime monitor setup key')"
  fi

  k3s_token="$(openssl rand -base64 64 | tr -d '\n')"
  {
    printf 'k3s_token: "%s"\n' "$k3s_token"
    printf 'netbird_k3s_nodes_setup_key: "%s"\n' "$netbird_k3s_nodes_setup_key"
    printf 'netbird_uptime_monitor_setup_key: "%s"\n' "$netbird_uptime_monitor_setup_key"
  } >"$secrets_file"
  chmod 600 "$secrets_file"
  append_trusted_cidrs_to_secrets
}

require ansible-vault
require ansible-playbook
require ansible-galaxy
require openssl

if [[ ! -f "$input_file" ]]; then
  printf 'Missing %s. Run scripts/terraform-apply-and-output.sh first.\n' "$input_file" >&2
  exit 1
fi

write_vault_password_file
set -a
# shellcheck disable=SC1090
. "$input_file"
set +a

if [[ -z "${K3S_SERVER_PUBLIC_IP:-}" || -z "${K3S_SERVER_PRIVATE_IP:-}" || -z "${SSH_PRIVATE_KEY_PATH:-}" ]]; then
  printf '%s is missing required values.\n' "$input_file" >&2
  exit 1
fi

uptime_monitor_values_available=false
if [[ -n "${UPTIME_MONITOR_PUBLIC_IP:-}" && -n "${UPTIME_MONITOR_PRIVATE_IP:-}" && -n "${UPTIME_MONITOR_SSH_PRIVATE_KEY_PATH:-}" ]]; then
  uptime_monitor_values_available=true
  printf '\nStandalone uptime monitor:\n'
  printf '  Public IP:  %s\n' "$UPTIME_MONITOR_PUBLIC_IP"
  printf '  Private IP: %s\n' "$UPTIME_MONITOR_PRIVATE_IP"
  printf '  SSH: ssh -i %q %s@%s\n' "$UPTIME_MONITOR_SSH_PRIVATE_KEY_PATH" "$ansible_user" "$UPTIME_MONITOR_PUBLIC_IP"
else
  printf 'Uptime monitor values are missing from %s; rerun scripts/00-terraform-apply-and-output.sh to refresh it.\n' "$input_file" >&2
fi

if ! confirm "Overwrite generated group vars and secrets with Terraform values?"; then
  printf 'Aborted.\n'
  exit 1
fi

mkdir -p "$all_dir"
decrypt_group_vars_if_needed

{
  printf 'k3s_server_private_ip: "%s"\n' "$K3S_SERVER_PRIVATE_IP"
} >"$all_file"

write_cluster_secrets_if_needed

{
  printf 'k3s_server_ansible_host: "%s"\n' "$K3S_SERVER_PUBLIC_IP"
  printf 'k3s_server_ansible_user: "%s"\n' "$ansible_user"
  printf 'k3s_server_ansible_ssh_private_key_file: "%s"\n' "$SSH_PRIVATE_KEY_PATH"
} >"$server_file"

{
  agent_count="${K3S_AGENT_COUNT:-0}"
  for ((i = 1; i <= agent_count; i++)); do
    public_var="K3S_AGENT_${i}_PUBLIC_IP"
    agent_public_ip="${!public_var:-}"

    if [[ -z "$agent_public_ip" ]]; then
      printf 'Missing %s in %s\n' "$public_var" "$input_file" >&2
      exit 1
    fi

    if (( i > 1 )); then
      printf '\n'
    fi

    printf 'k3s_agent_%s_ansible_host: "%s"\n' "$i" "$agent_public_ip"
    printf 'k3s_agent_%s_ansible_user: "%s"\n' "$i" "$ansible_user"
    printf 'k3s_agent_%s_ansible_ssh_private_key_file: "%s"\n' "$i" "$SSH_PRIVATE_KEY_PATH"
  done
} >"$agent_file"

if [[ "$uptime_monitor_values_available" == true ]]; then
  {
    printf 'uptime_monitor_ansible_host: "%s"\n' "$UPTIME_MONITOR_PUBLIC_IP"
    printf 'uptime_monitor_ansible_user: "%s"\n' "$ansible_user"
    printf 'uptime_monitor_ansible_ssh_private_key_file: "%s"\n' "$UPTIME_MONITOR_SSH_PRIVATE_KEY_PATH"
  } >"$uptime_monitor_file"
fi

printf '\nUpdated:\n'
printf '  %s\n' "$all_file"
printf '  %s\n' "$server_file"
printf '  %s\n' "$agent_file"
printf '  %s (gitignored)\n' "$secrets_file"
if [[ "$uptime_monitor_values_available" == true ]]; then
  printf '  %s\n' "$uptime_monitor_file"
fi

if ! confirm "Have you reviewed those files and want to encrypt the tracked group vars now?"; then
  printf 'Leaving group_vars decrypted for review. Run ansible/encrypt.sh when ready.\n'
  exit 0
fi

encrypt_group_vars

if confirm "Apply ansible/playbook.yml now?"; then
  install_ansible_requirements

  ansible-playbook \
    --vault-password-file "$vault_password_file" \
    -i "$ansible_dir/inventory.yml" \
    "$ansible_dir/playbook.yml"
fi

if [[ "$uptime_monitor_values_available" == true ]] && confirm "Apply ansible/playbooks/06-uptime-monitor-config.yml now?"; then
  install_ansible_requirements

  ansible-playbook \
    --vault-password-file "$vault_password_file" \
    -i "$ansible_dir/inventory.yml" \
    "$ansible_dir/playbooks/06-uptime-monitor-config.yml"
fi
