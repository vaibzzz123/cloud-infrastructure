# AGENTS.md

This file gives project-specific guidance to coding agents working in this repository.

## Project Summary

This repo provisions and operates a small self-managed k3s cluster on Oracle Cloud Infrastructure (OCI).

Primary workflow:
1. Terraform in `terraform/` creates the OCI network and compute.
2. Ansible in `ansible/` configures the hosts and installs k3s using `k3s-ansible`.
3. Plain Kubernetes manifests in `kubernetes/` install storage, TLS, secret management, and the app stack.

## Repo Layout

- `terraform/`
  - `main.tf`: OCI VCN, subnet, security list, `k3s-server`, and `k3s-agent-*` instances
  - `variables.tf`, `data.tf`, `outputs.tf`, `terraform.tfvars.example`
- `ansible/`
  - `requirements.yml`: pulls `k3s-ansible`
  - `inventory.yml`: cluster hosts, token wiring, pinned k3s version, and API endpoint
  - `playbook.yml`: apt updates, firewall rules, and `k3s.orchestration.site`
  - `group_vars/*.yml`: ansible-vault encrypted environment-specific secrets and host vars
- `kubernetes/`
  - `01-sealed-secrets/00-manifest.yml`: generated vendored Sealed Secrets manifest
  - `02-cert-manager/01-manifest.yml`: generated vendored cert-manager manifest
  - `03-longhorn/01-manifest.yml`: generated vendored Longhorn manifest
  - `04-caddy/`: handwritten application manifests
  - `main.yml`: scratch/example manifest, not the main deployed workload

## Important Platform Assumptions

- The cluster is k3s, not kubeadm.
- Traefik is the expected ingress controller unless explicitly disabled during k3s install.
- Longhorn is the default `StorageClass` for PVCs.
- cert-manager handles ACME and Let's Encrypt certificates via the `letsencrypt-production` `ClusterIssuer`.
- The Caddy stack is a single-replica Deployment with a two-container Pod: `caddy` and `netbird`.
- Sensitive values should stay either in ansible-vault files or Sealed Secrets, not in plain YAML.

## Docs And External References

Use current docs whenever the task is about a library, framework, SDK, API, CLI tool, or cloud service.

Use the `ctx7` CLI first for:
- Kubernetes
- k3s
- Terraform
- OCI
- Ansible
- Longhorn
- cert-manager
- Sealed Secrets
- Caddy
- NetBird

Workflow:
1. `npx ctx7@latest library <official name> "<full user question>"`
2. Pick the best `/org/project` match.
3. `npx ctx7@latest docs <libraryId> "<full user question>"`

Rules:
- Use the official library or product name.
- Use the user's full question as the query.
- Do not run more than 3 `ctx7` commands per question.
- Do not put secrets, tokens, private keys, or private config into queries.
- If `ctx7` hits a quota error, tell the user and suggest `npx ctx7@latest login` or setting `CONTEXT7_API_KEY`.

## Editing Guidance

- Read nearby files before changing patterns; this repo is small enough that local consistency matters more than abstraction.
- Prefer small, targeted edits over broad rewrites.
- Preserve plain YAML unless the user explicitly asks to adopt Helm, Kustomize, or another deployment system.
- Treat `kubernetes/01-sealed-secrets/00-manifest.yml`, `kubernetes/02-cert-manager/01-manifest.yml`, and `kubernetes/03-longhorn/01-manifest.yml` as generated vendor manifests.
- Prefer regenerating large vendor manifests from their upstream source commands or comments rather than hand-editing deep inside them.
- Keep handwritten app changes in `kubernetes/04-caddy/` unless the task clearly requires platform-level edits.
- Keep comments minimal and practical.

## Safety

- Never commit decrypted vault files, private keys, kubeconfigs, Terraform state, or plain `terraform.tfvars`.
- If you must inspect `ansible/group_vars/*.yml`, keep them encrypted again in the final state.
- Be cautious with firewall, ingress, storage, and public-IP changes; they can lock the user out or break cluster access.
- Do not rotate or reseal secrets unless the task requires it.
- Call out any change that can cause downtime, data loss, certificate re-issuance, or cluster access risk.

## Validation

Run the lightest relevant checks you can after changes:
- Terraform: from `terraform/`, run `terraform fmt -recursive` and `terraform validate` if the directory is initialized.
- Ansible: from `ansible/`, run `ansible-playbook --syntax-check -i inventory.yml playbook.yml` when dependencies are available.
- Kubernetes manifests: prefer `kubectl apply --dry-run=client -f <file>` for built-in resources when `kubectl` is available.
- If a manifest depends on CRDs that are not installed locally, validate YAML structure and explain the limitation.
- If a required tool or credential is unavailable, say so clearly.

## Current Repo Notes

- `ansible/requirements.yml` tracks `k3s-ansible` from `main`, so behavior can drift over time.
- `kubernetes/04-caddy/06-ingress.yml` should prefer `spec.ingressClassName` for modern Ingress resources.
- `terraform/main.tf` currently exposes SSH, HTTP, HTTPS, and the Kubernetes API publicly; treat security changes here carefully.
- `terraform/outputs.tf` is the main handoff point from provisioning to host access.

## When Unsure

- Start by understanding the Terraform -> Ansible -> Kubernetes flow before changing files.
- Prefer consistency with the current repo over generic best-practices rewrites.
- Surface tradeoffs before making disruptive infra changes.
