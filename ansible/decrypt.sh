#!/usr/bin/env bash
set -Eeuo pipefail

vault_files=(
  group_vars/all.yml
  group_vars/server.yml
  group_vars/agent.yml
)

existing_files=()
for file in "${vault_files[@]}"; do
  if [[ -f "$file" ]]; then
    existing_files+=("$file")
  fi
done

if (( ${#existing_files[@]} == 0 )); then
  printf 'No vault files found to decrypt.\n' >&2
  exit 1
fi

ansible-vault decrypt "${existing_files[@]}" --vault-password-file group_vars/.vault_password
