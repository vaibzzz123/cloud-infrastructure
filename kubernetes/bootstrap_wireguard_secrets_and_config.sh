#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
ansible_dir="$repo_root/ansible"
inventory_file="$ansible_dir/inventory.yml"
playbook_file="$ansible_dir/playbooks/04-wireguard-keypairs-config.yml"
pod_config_file="$script_dir/04-caddy/wg0.conf"
pod_private_key_file="$HOME/.wireguard/caddy-pod-private.key"
sealed_secret_script="$script_dir/create_wireguard_sealed_secret.sh"
vault_password_file="$ansible_dir/group_vars/.vault_password"
ansible_vault_args=()
vault_option_supplied=false

confirm() {
  local prompt="$1"
  local answer
  read -r -p "$prompt [y/N] " answer
  [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}

for required_file in "$inventory_file" "$playbook_file" "$sealed_secret_script"; do
  if [[ ! -f "$required_file" ]]; then
    printf 'Missing required file: %s\n' "$required_file" >&2
    exit 1
  fi
done

if ! command -v ansible-playbook >/dev/null 2>&1; then
  printf 'Missing required command: ansible-playbook\n' >&2
  exit 1
fi

for argument in "$@"; do
  case "$argument" in
    --ask-vault-pass|--vault-password-file|--vault-password-file=*|--vault-id|--vault-id=*)
      vault_option_supplied=true
      ;;
  esac
done

if [[ "$vault_option_supplied" == false ]]; then
  if [[ ! -r "$vault_password_file" ]]; then
    printf 'Missing or unreadable Vault password file: %s\n' "$vault_password_file" >&2
    printf 'Pass --ask-vault-pass or an explicit --vault-id/--vault-password-file instead.\n' >&2
    exit 1
  fi

  ansible_vault_args=(--vault-password-file "$vault_password_file")
fi

if [[ -e "$pod_config_file" ]] && ! confirm "Overwrite $pod_config_file?"; then
  printf 'Leaving the existing Pod WireGuard configuration unchanged.\n'
  exit 0
fi

printf 'Choose WireGuard key handling:\n'
printf '  1) Generate missing keypairs (recommended)\n'
printf '  2) Use manually supplied private keys\n'
read -r -p 'Selection [1/2]: ' key_choice

case "$key_choice" in
  1)
    wireguard_key_source=generate
    ;;
  2)
    wireguard_key_source=manual
    mkdir -p -m 0700 "$(dirname "$pod_private_key_file")"

    if [[ ! -s "$pod_private_key_file" ]] || confirm "Replace $pod_private_key_file?"; then
      if ! command -v wg >/dev/null 2>&1; then
        printf 'Missing required command for manual key validation: wg\n' >&2
        exit 1
      fi

      local_pod_private_key=''
      read -r -s -p 'Enter the Caddy Pod private key: ' local_pod_private_key
      printf '\n'
      if [[ -z "$local_pod_private_key" ]] || ! printf '%s' "$local_pod_private_key" | wg pubkey >/dev/null 2>&1; then
        printf 'The supplied Caddy Pod private key is not valid.\n' >&2
        exit 1
      fi

      (umask 077 && printf '%s\n' "$local_pod_private_key" >"$pod_private_key_file")
      unset local_pod_private_key
    fi

    printf '\nBefore continuing, create the homeserver private key directly on the homeserver:\n'
    printf '  install -d -m 700 ~/.wireguard\n'
    printf '  umask 077; printf "%%s\\n" "<homeserver-private-key>" > ~/.wireguard/wireguard-private.key\n\n'
    read -r -p 'Press Enter once that file exists on the homeserver. ' continue_prompt
    ;;
  *)
    printf 'Invalid selection.\n' >&2
    exit 1
    ;;
esac

ansible-playbook "${ansible_vault_args[@]}" "$@" -i "$inventory_file" "$playbook_file" \
  --tags wireguard-keypairs \
  --extra-vars "wireguard_key_source=$wireguard_key_source"

ansible-playbook "${ansible_vault_args[@]}" "$@" -i "$inventory_file" "$playbook_file" \
  --tags wireguard-config

"$sealed_secret_script"

printf 'WireGuard configurations and SealedSecret generated successfully.\n'
