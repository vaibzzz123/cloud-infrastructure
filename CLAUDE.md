# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform infrastructure-as-code repository for managing cloud resources.

## Commands

```bash
# Initialize Terraform (download providers, set up backend)
terraform init

# Format all Terraform files
terraform fmt -recursive

# Validate configuration syntax
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy resources
terraform destroy
```

## Project Structure

- `main.tf` - Primary infrastructure definitions
- `*.tfvars` - Variable values (gitignored, contains sensitive data)
- `.terraform/` - Provider plugins and modules (gitignored)

## Conventions

- Use `terraform fmt` before committing to ensure consistent formatting
- Run `terraform validate` to catch syntax errors before planning
- Variable definitions typically go in `variables.tf`, outputs in `outputs.tf`
