#!/usr/bin/env bash
# Quick sanity checks before terraform apply / ansible-playbook.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> engagements/current.json exists"
test -f engagements/current.json || {
  echo "ERROR: Create an engagement first (e.g. ./engagement-manager.sh start) or copy Terraform outputs into current.json."
  exit 1
}

echo "==> infrastructure section populated (Terraform outputs)"
python3 << 'PY'
import json
import sys
p = "engagements/current.json"
with open(p) as f:
    d = json.load(f)
infra = d.get("infrastructure") or {}
if not infra:
    print("ERROR: 'infrastructure' is empty — run terraform apply and merge outputs into current.json.")
    sys.exit(1)
need = ("redirector_public_ip", "mythic_private_ip", "gophish_private_ip", "evilginx_private_ip", "pwndrop_private_ip")
missing = [k for k in need if not infra.get(k)]
if missing:
    print("WARNING: missing keys (Ansible may skip hosts):", ", ".join(missing))
PY

echo "==> base_domain in access_info"
python3 -c "import json; d=json.load(open('engagements/current.json')); assert d.get('access_info',{}).get('base_domain'), 'base_domain missing'"

echo "==> tools"
command -v ansible-playbook >/dev/null && echo "  ansible-playbook: OK" || { echo "  ansible-playbook: MISSING"; exit 1; }
command -v terraform >/dev/null && echo "  terraform: OK" || echo "  terraform: not in PATH (optional for local checks)"

echo "OK: pre-deployment checks passed (review any WARNINGs)."
