#!/usr/bin/env bash
# Validate Terraform and Ansible syntax (see .cursor/rules/general.md).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Ansible syntax-check (site.yml + dynamic inventory)"
cd ansible
ansible-playbook --syntax-check -i inventory/terraform_inventory.py site.yml
cd "$ROOT"

if [[ -d cloud-configs/gcp/terraform ]]; then
  echo "==> terraform validate (GCP)"
  cd cloud-configs/gcp/terraform
  terraform init -backend=false -input=false >/dev/null
  terraform validate
  cd "$ROOT"
fi

if [[ -d cloud-configs/azure/terraform ]]; then
  echo "==> terraform validate (Azure)"
  cd cloud-configs/azure/terraform
  if terraform init -backend=false -input=false >/dev/null 2>&1; then
    terraform validate
  else
    echo "(skipped: terraform init failed — install providers or run from configured env)"
  fi
  cd "$ROOT"
fi

echo "OK: IaC validation finished."
