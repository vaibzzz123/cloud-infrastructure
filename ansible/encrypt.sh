#!/usr/bin/env bash
set -Eeuo pipefail

vault_files=(
  group_vars/all/main.yml
  group_vars/server.yml
  group_vars/agent.yml
  group_vars/uptime_monitor.yml
)

plaintext_files=()
for file in "${vault_files[@]}"; do
  if [[ -f "$file" ]]; then
    IFS= read -r first_line <"$file" || true
    if [[ "$first_line" != '$ANSIBLE_VAULT;'* ]]; then
      plaintext_files+=("$file")
    fi
  fi
done

if (( ${#plaintext_files[@]} == 0 )); then
  printf 'All existing vault files are already encrypted.\n'
  exit 0
fi

ansible-vault encrypt "${plaintext_files[@]}" --vault-password-file group_vars/.vault_password
