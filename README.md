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
