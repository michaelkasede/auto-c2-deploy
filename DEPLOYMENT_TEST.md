# Deployment test checklist

Use this before a full end-to-end test of **Terraform + Ansible** for this repo.

For **everything an operator must supply** (prompts, env vars, files), see **README.md** (section **Operator inputs for deployment**).

## 1. Prerequisites

| Item | Notes |
|------|--------|
| Cloud credentials | `gcloud` / `az` / `aws` logged in; do not commit keys (see `.cursor/rules/multi-cloud.md`). |
| `engagements/current.json` | Must include **`infrastructure`** from Terraform outputs (IPs). Empty `infrastructure` → Ansible skips all hosts. |
| `DUCKDNS_TOKEN` + `CERTBOT_EMAIL` | Required in the **same shell** as Ansible for redirector **DNS-01** wildcard certs (DuckDNS). |
| `GCP_PROJECT_ID` (+ optional `CLOUD_REGION`) | Required for **GCP** before `./engagement-manager.sh start` (see README). |
| SSH keys | Terraform uses `SSH_PUBLIC_KEY_PATH` (default `~/.ssh/id_rsa.pub`). Ansible uses `SSH_KEY_PATH` (default `~/.ssh/id_rsa`) for jump-host access to private VMs. |
| `ansible-playbook`, `terraform`, `python3`, `jq` | Used by scripts and inventory. |

Ansible collections: `ansible/collections/requirements.yml` may be empty (roles use `ansible.builtin` only). Install only if you add collections later.

## 2. Run order

1. **Terraform** apply for your provider (`cloud-configs/<provider>/terraform`), or run **`./engagement-manager.sh start`** (runs `deploy-stealth.sh` → Terraform).
2. Merge **`terraform output -json`** into **`engagements/current.json`** → **`infrastructure`** (the engagement manager does this when deployment finishes).
3. **DNS**: Point `A`/`CNAME` records for apex, `*`, `api`, `mail`, `login`, `cdn`, `ops` at the **redirector public IP** (script prompts for confirmation).
4. **`./scripts/pre-deployment-check.sh`**
5. **`./scripts/validate-iac.sh`**
6. If SSH fails with host-key mismatch after a **new** deploy:  
   `ssh-keygen -f "$HOME/.ssh/known_hosts" -R '<REDIRECTOR_PUBLIC_IP>'`
7. **`cd ansible && ansible-playbook -i inventory/terraform_inventory.py site.yml`**

## 3. What each VM should get

| VM | Role | Outcome |
|----|------|---------|
| **redirector** | `redirector` | Nginx (stream SNI + `http` on internal TLS port), Certbot + DuckDNS wildcard for `base_domain` + `*.base_domain`, static decoy site, smart redirector vhost. |
| **mythic, gophish, evilginx, pwndrop** | Cert play | Wildcard cert/key copied to **`/etc/aegis/certs/`** (from redirector). |
| **mythic** | `mythic` | Docker, **its-a-feature/Mythic**, certs under `nginx-docker/ssl/`, `mythic-cli start`, profiles/agents. |
| **gophish** | `gophish` | Release binary under `/opt/gophish`, `config.json`, **systemd** (TLS terminated on redirector). |
| **evilginx** | `evilginx` | Build from source → `/opt/evilginx2/build/evilginx`; systemd + **`script`** (PTY) + `-developer`. |
| **pwndrop** | `pwndrop` | Binary in `/usr/local/bin`, systemd; HTTP port aligned with `pwndrop_http_port` / redirector upstream (default **80**). |

## 4. Known limitations

- **Evilginx2** is interactive; the unit runs it under **`script`** for a PTY. If the service fails, check `journalctl -u evilginx`.
- **Mythic** needs the cert-distribution play before Mythic-specific TLS paths are correct; avoid `--limit mythic` on first run without certs.
- **Stealth + Nginx:** High/Medium stealth may install **`/etc/nginx/snippets/aegis-disable-metrics.conf`**; snippets live under **`http{}`**.

## 5. Smoke tests (after deploy)

```bash
# Redirector: HTTPS (use base_domain from current.json)
curl -Iks "https://$(jq -r .access_info.base_domain engagements/current.json)/"

# From operator: SSH to redirector, then nginx + certs
ssh ubuntu@"$(jq -r '.infrastructure.redirector_public_ip.value // .infrastructure.redirector_public_ip' engagements/current.json)" 'sudo nginx -t && sudo ls /etc/letsencrypt/live/'
```
