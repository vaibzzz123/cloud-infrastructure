#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ansible_dir="$repo_root/ansible"
group_vars_dir="$ansible_dir/group_vars"
input_file="${TERRAFORM_OUTPUT_FILE:-$repo_root/.local/terraform-outputs.env}"
vault_password_file="$group_vars_dir/.vault_password"
ansible_user="${ANSIBLE_USER:-ubuntu}"
all_dir="$group_vars_dir/all"
all_file="$all_dir/main.yml"
server_file="$group_vars_dir/server.yml"
agent_file="$group_vars_dir/agent.yml"
secrets_file="$all_dir/secrets.yml"

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
  if is_encrypted "$all_file" || is_encrypted "$server_file" || is_encrypted "$agent_file"; then
    (cd "$ansible_dir" && ./decrypt.sh)
  fi
}

encrypt_group_vars() {
  (cd "$ansible_dir" && ./encrypt.sh)
}

write_k3s_token_if_needed() {
  local k3s_token

  if [[ -f "$secrets_file" ]]; then
    chmod 600 "$secrets_file"

    if ! confirm "$secrets_file already exists. Regenerate k3s_token?"; then
      printf 'Keeping existing %s\n' "$secrets_file"
      return 0
    fi
  fi

  k3s_token="$(openssl rand -base64 64 | tr -d '\n')"
  {
    printf 'k3s_token: "%s"\n' "$k3s_token"
  } >"$secrets_file"
  chmod 600 "$secrets_file"
}

require ansible-vault
require ansible-playbook
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

if ! confirm "Overwrite group_vars/all/main.yml, server.yml, and agent.yml with Terraform values?"; then
  printf 'Aborted.\n'
  exit 1
fi

mkdir -p "$all_dir"
decrypt_group_vars_if_needed

{
  printf 'k3s_server_private_ip: "%s"\n' "$K3S_SERVER_PRIVATE_IP"
} >"$all_file"

write_k3s_token_if_needed

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

printf '\nUpdated:\n'
printf '  %s\n' "$all_file"
printf '  %s\n' "$server_file"
printf '  %s\n' "$agent_file"
printf '  %s (gitignored)\n' "$secrets_file"

if ! confirm "Have you reviewed those files and want to encrypt the tracked group vars now?"; then
  printf 'Leaving group_vars decrypted for review. Run ansible/encrypt.sh when ready.\n'
  exit 0
fi

encrypt_group_vars

if confirm "Apply ansible/playbook.yml now?"; then
  ansible-playbook \
    --vault-password-file "$vault_password_file" \
    -i "$ansible_dir/inventory.yml" \
    "$ansible_dir/playbook.yml"
fi
