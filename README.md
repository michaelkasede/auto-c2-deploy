# Multi-Cloud Red Team Infrastructure (Auto-c2-deploy)

Standalone multi-cloud Terraform + Ansible for red team infrastructure (redirector, Mythic, GoPhish, Evilginx, Pwndrop).

## Operator inputs for deployment

Collect these **before** you run `./engagement-manager.sh start` (or before manual Terraform). Values are **required** unless marked optional.

### 1. Interactive prompts (`./engagement-manager.sh start`)

| Input | Required | Description |
|--------|----------|-------------|
| **Engagement name** | Yes | Identifier for this run (e.g. `client-2024-03`). Used as Terraform `environment` / state naming. |
| **Client name** | Yes | Label for reporting. |
| **Duration (days)** | Yes | Stored in engagement metadata. |
| **Cloud provider** | Yes | `aws`, `azure`, or `gcp` (default `aws` if Enter). |
| **Region** | Yes* | GCP default `us-east4` if Enter; **AWS** prompts with no default — you must set a region. Azure default `centralus`. |
| **Stealth level** | No | `high` (default), `medium`, or `low` — affects monitoring/cron behavior in Ansible. |
| **Deployment mode** | No | `primary` (default) or `backup`. |
| **Base domain** | Yes | Apex DNS name used for certs and vhosts (e.g. `zoom-meeting.duckdns.org`). Drives `api.`, `mail.`, `login.`, `cdn.`, `ops.` automatically. |
| **Decoy site URL** | No | Shown in metadata; default `https://wordpress.org`. Used for redirector decoy context. |
| **Operator allowlist** | No | Comma-separated **source CIDRs** allowed as “operators” on `ops.<base_domain>` (default: your current public IP `/32` from `ifconfig.me`). Empty list in Ansible means all clients are treated as operators on `ops.*`. |
| **Confirm start** | Yes | `y` to proceed. |

After Terraform completes, the script prompts for:

| Input | Required | Description |
|--------|----------|-------------|
| **Redirector public IP** | Yes | Confirms the IP from Terraform (or paste from cloud console). Used to print **DNS instructions** for all hostnames pointing at the redirector. |
| **DNS propagation** | Yes | Press Enter only after **A/CNAME** records for apex, `*`, `api`, `mail`, `login`, `cdn`, `ops` point at that IP. |

### 2. Environment variables (shell that runs Terraform / Ansible)

Set these in the **same shell** as `./engagement-manager.sh start` (child processes inherit them).

| Variable | When | Required | Description |
|----------|------|----------|-------------|
| **`GCP_PROJECT_ID`** | GCP | **Yes** | Google Cloud project ID. `deploy-stealth.sh` defaults to `aegis-auto-c2` only if unset — set your real project. |
| **`CLOUD_REGION`** | GCP (optional) | No | Overrides default region (e.g. `us-east4`). Engagement manager also sets `CLOUD_REGION` from your interactive region choice. |
| **`DUCKDNS_TOKEN`** | TLS + DuckDNS | **Yes** for DNS-01 | DuckDNS API token for TXT challenges. |
| **`CERTBOT_EMAIL`** | TLS | **Yes** | Let’s Encrypt account / contact email (redirector Certbot). |
| **`DUCKDNS_PROPAGATION_SECONDS`** | TLS (optional) | No | Overrides default wait after TXT update before LE checks (redirector role default is `180`). |
| **`SSH_PUBLIC_KEY_PATH`** | Terraform | No | Path to **public** key for `ubuntu` on all VMs (default `~/.ssh/id_rsa.pub`). Must match the private key you use to SSH. |
| **`SSH_KEY_PATH`** | Ansible | No | Path to **private** key for Ansible SSH (default `~/.ssh/id_rsa`). Inventory uses this for the redirector and **ProxyCommand** to private IPs. |

**Note:** `deploy-stealth.sh` passes **`OPERATOR_ALLOWLIST`** (comma-separated) from the engagement manager into Terraform as **`admin_ip`** for firewall `source_ranges`. If you use **multiple** CIDRs, ensure your Terraform provider accepts the string format you use (for a single strict CIDR, use one operator `/32` or edit `terraform.tfvars` manually).

### 3. Files and generated state

| Path | Required | Description |
|------|----------|-------------|
| **`engagements/current.json`** | Yes (after start) | Engagement + **`access_info.base_domain`** + **`infrastructure`** (Terraform outputs: redirector public IP, private IPs per service). Ansible dynamic inventory reads this file. |
| **`outputs/<provider>_<mode>.json`** | Produced by Terraform | Merged into `current.json` by the engagement manager. |
| **Cloud credentials** | Yes | `gcloud auth login` / `aws configure` / `az login` as appropriate — not stored in the repo. |

### 4. Post-deploy: SSH host keys

Each `./engagement-manager.sh start` provisions new VMs and may change the **redirector public IP** and host keys. If SSH fails with a host-key mismatch, remove the stale entry:

```bash
ssh-keygen -f "$HOME/.ssh/known_hosts" -R '<REDIRECTOR_PUBLIC_IP>'
```

Then rerun Ansible or SSH again.

---

## Quick start

```bash
cd /path/to/Auto-c2-deploy

# GCP example: set project + optional region + certbot + DuckDNS
export GCP_PROJECT_ID="your-gcp-project-id"
export CLOUD_REGION="us-east4"
export CERTBOT_EMAIL="you@example.com"
export DUCKDNS_TOKEN="your_duckdns_token"

./engagement-manager.sh start
```

Check status / stop:

```bash
./engagement-manager.sh --status
./engagement-manager.sh stop
```

### Validate IaC (Terraform + Ansible)

From the repo root:

```bash
./scripts/validate-iac.sh
./scripts/pre-deployment-check.sh
```

Full checklist: **`DEPLOYMENT_TEST.md`**.

### Manual Ansible (if not using the manager’s Ansible step)

```bash
cd ansible
ansible-playbook -i inventory/terraform_inventory.py site.yml
```

Inventory is **`ansible/inventory/terraform_inventory.py`**; it reads **`engagements/current.json`**. Private service hosts use the **redirector** as **ProxyCommand** jump host when `redirector_public_ip` is present under `infrastructure`.

---

## Environment variables (DuckDNS + Certbot)

If you use DuckDNS for **DNS-01** wildcard validation, export these in the shell where Ansible runs (including the engagement manager flow):

```bash
export DUCKDNS_TOKEN="YOUR_DUCKDNS_TOKEN"
export CERTBOT_EMAIL="your_email@example.com"
```

### How Certbot is used

- **`certbot_email`** — Set from `CERTBOT_EMAIL` for Certbot invocations.
- **Assert** — On HTTP-01 paths, Ansible may fail fast if `CERTBOT_EMAIL` is missing (see redirector role).
- **Wildcard** — Typically one certificate for `base_domain` and `*.base_domain` (DuckDNS DNS-01).
- **Renewal** — `certbot renew` uses the existing LE account.

### Certificate distribution

After the redirector obtains the wildcard, `ansible/site.yml` copies `fullchain.pem` and `privkey.pem` to private VMs at `/etc/aegis/certs/`.

**Manual fallback:** SSH to the redirector, archive `/etc/letsencrypt/live/<base_domain>/`, `scp` via `ProxyJump` to each private host, and install under `/etc/aegis/certs/` with `privkey.pem` mode `0600` and `fullchain.pem` `0644`.

### GCP project ID

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
```

Optional region override:

```bash
export CLOUD_REGION="us-east4"
```

---

## Directory layout (high level)

```
├── engagement-manager.sh          # Engagement lifecycle + Terraform + Ansible
├── deploy-stealth.sh              # Terraform deploy (used by engagement manager)
├── engagements/current.json       # Active engagement + infrastructure IPs
├── ansible/
│   ├── site.yml
│   ├── inventory/terraform_inventory.py
│   └── roles/
├── cloud-configs/<provider>/terraform/
├── scripts/
│   ├── validate-iac.sh
│   └── pre-deployment-check.sh
├── DEPLOYMENT_TEST.md
└── decoy-website/                 # Static decoy assets (redirector)
```

---

## Features

- Terraform + Ansible for AWS, Azure, GCP
- Central redirector (Nginx, TLS, stream routing)
- Private-VM services (Mythic uses Docker; others use systemd binaries)

## Cloud provider options

1. **AWS** — Default in some prompts  
2. **Azure**  
3. **GCP**  
4. **Multi** — Deploy to multiple providers (when using `deploy-stealth.sh` / `deploy-standalone.sh` interactively)

## Deployment modes

- **Primary** — Full stack  
- **Backup** — Minimal / standby

## Dependencies

- Terraform >= 1.0  
- Python 3.8+  
- `ansible-playbook`, `jq`  
- Cloud CLI (`aws`, `az`, or `gcloud`) for the provider you use  
- Docker is installed **on the Mythic host only** by Ansible (not required on your laptop)

## Documentation

- **`DEPLOYMENT_TEST.md`** — Pre-flight checklist and smoke tests  
- **`MULTI_CLOUD_README.md`** — Multi-cloud notes  
- **`AWS_REDTEAM_README.md`** — AWS-specific notes  

---

This repository is a standalone deployment toolkit for lab / authorized engagement use.
