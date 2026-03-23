# Deployment test checklist

Use this before a full end-to-end test of **Terraform + Ansible** for this repo.

## 1. Prerequisites

| Item | Notes |
|------|--------|
| Cloud credentials | `gcloud` / `az` / `aws` logged in; **no** keys in repo (see `.cursor/rules/multi-cloud.md`). |
| `engagements/current.json` | Must include **`infrastructure`** from Terraform outputs (IPs). Empty `infrastructure` → Ansible skips all hosts. |
| `DUCKDNS_TOKEN` + `CERTBOT_EMAIL` | Required for redirector **DNS-01** wildcard certs (same shell as Ansible). |
| Ansible collections | `ansible-galaxy collection install -r ansible/collections/requirements.yml` (needed for `community.docker` if `stealth_level` is `low`). |

## 2. Run order

1. **Terraform** apply for your provider (`cloud-configs/<provider>/terraform`).
2. Merge **`terraform output -json`** (or your script output) into **`engagements/current.json`** → `infrastructure`.
3. **`./scripts/pre-deployment-check.sh`**
4. **`./scripts/validate-iac.sh`**
5. **`cd ansible && ansible-playbook -i inventory/terraform_inventory.py site.yml`**

## 3. What each VM should get

| VM | Role | Outcome |
|----|------|---------|
| **redirector** | `redirector` | Nginx, Certbot + DuckDNS (`certbot-dns-duckdns`), wildcard cert for `base_domain` + `*.base_domain`, decoy `docker compose`, smart redirector vhost, `nginx -t` validation. |
| **mythic, gophish, evilginx, pwndrop** | (play) | Wildcard cert/key copied to **`/etc/aegis/certs/`** (from redirector). |
| **mythic** | `mythic` | Docker via get.docker.com, clone **its-a-feature/Mythic**; if `/etc/aegis/certs` exists, copies **`fullchain.pem`** / **`privkey.pem`** to **`/opt/mythic/nginx-docker/ssl/`** (maps to **`/etc/ssl/private`** in `mythic_nginx`) and patches **`nginx-docker/config/templates/services.conf.template`** for those paths; then `make` mythic-cli, `./mythic-cli start`, profiles/agents. |
| **gophish** | `gophish` | If `/etc/aegis/certs` exists, stages **`gophish_admin.crt`** / **`gophish_admin.key`** into `/opt/gophish/ssl` for admin HTTPS; then `docker compose up`. |
| **evilginx** | `evilginx` | Build from source; systemd runs evilginx under **`script`** (PTY) with **`-developer`** (self-signed); redirector uses **proxy_ssl_verify off**. |
| **pwndrop** | `pwndrop` | Binary + systemd; HTTP on 8080 (redirector terminates TLS). |

## 4. Known limitations

- **Evilginx2** is designed as an interactive CLI; the unit file runs it under **`script`** so readline works under systemd. If the service fails, check `journalctl -u evilginx` and confirm `/opt/evilginx2/phishlets` exists.
- **Mythic** nginx uses certs from **`nginx-docker/ssl/`** on the host (synced from `/etc/aegis/certs` before `mythic-cli start`). If you run **`--limit mythic`** without the distribute-certs play first, `/etc/aegis/certs` may be missing and Mythic will use the default template paths until you re-run the full playbook or copy certs manually.
- **`ssl` role** is not used in `site.yml` for these hosts; the redirector obtains the wildcard and private services consume `/etc/aegis/certs` where applicable.
- **Stealth + Nginx:** High/Medium stealth installs **`/etc/nginx/snippets/aegis-disable-metrics.conf`** and each **`server`** block includes it (files under **`conf.d/`** are in **`http{}`** and cannot contain raw **`location`** directives).

## 5. Smoke tests (after deploy)

```bash
# Redirector: HTTPS
curl -Iks "https://$(jq -r .access_info.base_domain engagements/current.json)/"

# From operator: SSH to redirector, then nginx + certs
ssh ubuntu@<REDIRECTOR_PUBLIC> 'sudo nginx -t && sudo ls /etc/letsencrypt/live/'
```
