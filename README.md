# Multi-Cloud Red Team Infrastructure

This directory contains a **standalone** multi-cloud deployment solution for red team infrastructure, completely separate from the Mythic project.

## Quick Start

```bash
cd multi-cloud-redteam
./deploy-standalone.sh
```

## Directory Structure

```
multi-cloud-redteam/
├── deploy-standalone.sh          # Standalone interactive deployment
├── deploy-interactive.sh          # Original interactive deployment
├── deploy-multi-cloud.sh           # Original multi-cloud script
├── generate-terraform-config.py     # Terraform config generator
├── configure-services.py           # Service configuration
├── update-dns.py                 # DNS failover management
├── test-failover.py              # Failover testing
├── MULTI_CLOUD_README.md          # Complete documentation
├── AWS_REDTEAM_README.md          # AWS-specific docs
├── templates/                     # Cloud-init templates
│   ├── cloud-init-mythic.sh
│   ├── cloud-init-gophish.sh
│   ├── cloud-init-evilginx.sh
│   └── cloud-init-pwndrop.sh
├── scripts/                       # Utility scripts
│   ├── configure-multi-operator.sh
│   ├── configure-stealth.sh
│   └── aws-redteam-deploy.sh
└── cloud-configs/                # Cloud-specific configs (created during deployment)
    ├── aws/
    ├── azure/
    └── gcp/
```

## Features

- **Standalone Deployment**: Completely separate from Mythic installation
- **Interactive Deployment**: Choose cloud provider and deployment mode
- **Multi-Cloud Support**: AWS, Azure, GCP with failover
- **AWS Default**: AWS is the default selection
- **Self-Contained**: All templates and scripts included
- **Modular Design**: Each component is separate and reusable

## Quick Start

### Start New Engagement
```bash
cd multi-cloud-redteam
./engagement-manager.sh start
```

## Environment Variables (DuckDNS + Certbot)
If you are using DuckDNS for your DNS-01 certificate validation, export the following variables in the same shell where you run `./engagement-manager.sh start` (Ansible inherits the environment from the parent process):

```bash
export DUCKDNS_TOKEN="YOUR_DUCKDNS_TOKEN"
export CERTBOT_EMAIL="your_email@example.com"
```

The redirector SSL automation reads these variables when invoking Certbot.

### How Certbot is used in this project
- **`certbot_email`** – At the start of the SSL/redirector roles, the contact email is set once from `CERTBOT_EMAIL` (trimmed) so every Certbot invocation uses the same value.
- **Assert** – On the HTTP-01 path (when `stealth_level != "high"`), Ansible fails immediately with a clear error if `CERTBOT_EMAIL` is missing or blank, so you fix it before any certificate requests run.
- **Certbot tasks** – Playbook tasks use the `{{ certbot_email }}` variable instead of an inline `lookup('env', …)` for consistency and readability.
- **DuckDNS DNS-01 wildcard cert** – The redirector requests one certificate for `{{ base_domain }}` and `*.{{ base_domain }}` (for example: `zoom-meeting.duckdns.org` and `*.zoom-meeting.duckdns.org`) to avoid DuckDNS multi-SAN TXT challenge issues.
- **Renewal** – Auto-renewal runs `certbot renew`, which does not take `--email`; the Let's Encrypt account (and renewals) stay tied to the account created when certificates were first requested with `CERTBOT_EMAIL`.

### Certificate distribution to private VMs
- **Automated by Ansible** – After the redirector obtains the wildcard certificate, `ansible/site.yml` copies:
  - `/etc/letsencrypt/live/<base_domain>/fullchain.pem`
  - `/etc/letsencrypt/live/<base_domain>/privkey.pem`
  to each private service VM (`mythic`, `gophish`, `evilginx`, `pwndrop`) at:
  - `/etc/aegis/certs/fullchain.pem`
  - `/etc/aegis/certs/privkey.pem`

### Manual fallback (if you need to copy certs yourself)
If you ever need to do this manually, first SSH to the redirector, copy certs locally, then transfer to private hosts:

```bash
# 1) SSH to redirector
ssh -i ~/.ssh/id_rsa ubuntu@<REDIRECTOR_PUBLIC_IP>

# 2) On redirector: package certs
sudo tar -czf /tmp/aegis-certs.tar.gz -C /etc/letsencrypt/live/<base_domain> fullchain.pem privkey.pem

# 3) From your local machine: download bundle
scp -i ~/.ssh/id_rsa ubuntu@<REDIRECTOR_PUBLIC_IP>:/tmp/aegis-certs.tar.gz .

# 4) Upload to a private VM via ProxyJump
scp -i ~/.ssh/id_rsa -o ProxyJump=ubuntu@<REDIRECTOR_PUBLIC_IP> aegis-certs.tar.gz ubuntu@<PRIVATE_VM_IP>:/tmp/

# 5) On each private VM: install certs
ssh -i ~/.ssh/id_rsa -J ubuntu@<REDIRECTOR_PUBLIC_IP> ubuntu@<PRIVATE_VM_IP> \
  'sudo mkdir -p /etc/aegis/certs && sudo tar -xzf /tmp/aegis-certs.tar.gz -C /etc/aegis/certs && sudo chmod 600 /etc/aegis/certs/privkey.pem && sudo chmod 644 /etc/aegis/certs/fullchain.pem'
```

### GCP project ID
When you choose **GCP** as the cloud provider, export your Google Cloud project ID in the same shell before running `./engagement-manager.sh start` (the deployment script reads it when generating Terraform config):

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
```

Optionally set the region (default is `us-east4`):

```bash
export CLOUD_REGION="us-east4"
```

### Check Engagement Status
```bash
cd multi-cloud-redteam
./engagement-manager.sh --status
```

### Stop Engagement
```bash
cd multi-cloud-redteam
./engagement-manager.sh stop
```

### SSL Certificate Setup
```bash
cd multi-cloud-redteam
./setup-ssl.sh outputs/aws_primary.json high
```

### DNS Failover Configuration
```bash
cd multi-cloud-redteam
python3 update-dns.py --create-config
# Edit dns-config.json with your domains and API keys
python3 update-dns.py --provider aws --target azure --all
```

## Cloud Provider Options

1. **AWS** (Default) - Primary production deployment
2. **Azure** - Backup or standalone deployment
3. **GCP** - Backup or standalone deployment
4. **Multi-Cloud** - Deploy to all providers

## Deployment Modes

- **Primary**: Full deployment with all services
- **Backup**: Minimal deployment for failover standby

## Templates Included

All cloud-init templates are included in the `templates/` directory:
- `cloud-init-mythic.sh` - Mythic C2 server setup
- `cloud-init-gophish.sh` - GoPhish phishing setup
- `cloud-init-evilginx.sh` - Evilginx phishing setup
- `cloud-init-pwndrop.sh` - Pwndrop file server setup

## Scripts Included

All utility scripts are included in the `scripts/` directory:
- `configure-multi-operator.sh` - Multi-operator access setup
- `configure-stealth.sh` - Security and stealth configurations
- `aws-redteam-deploy.sh` - AWS-specific deployment

## Dependencies

- Terraform >= 1.0
- Python 3.8+
- Cloud CLI tools (aws, az, gcloud)
- Docker and Docker Compose

## Documentation

- `MULTI_CLOUD_README.md` - Complete multi-cloud documentation
- `AWS_REDTEAM_README.md` - AWS-specific deployment guide

---

**Note**: This is a completely standalone deployment system that does not depend on any Mythic installation. All necessary templates and scripts are included within this directory.
