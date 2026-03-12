# Multi-Cloud Red Team Infrastructure

A comprehensive, stealth-enhanced multi-cloud deployment solution for red team operations with complete engagement lifecycle management.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/multi-cloud-redteam.git
cd multi-cloud-redteam

# Start your first engagement
./engagement-manager.sh start
```

## 📋 Features

### **Multi-Cloud Support**
- **AWS Primary**: Full deployment with all services
- **Azure Backup**: Redundant infrastructure for failover
- **GCP Backup**: Additional redundancy option
- **Automated Failover**: DNS-based failover with health checks

### **Services**
- **Mythic**: C2 framework for payload management
- **GoPhish**: Phishing campaign management
- **Evilginx**: Advanced phishing with session hijacking
- **Pwndrop**: Secure file serving

### **Stealth & Security**
- **Hybrid Monitoring**: Optimal balance of stealth and operational visibility
- **Domain Obfuscation**: Automated generation of defense-evading domains
- **SSL Certificate Management**: Automated Let's Encrypt setup with auto-renewal
- **Evidence Distribution**: Minimize centralization of operational data

### **Engagement Lifecycle**
- **Launch**: Interactive deployment with cloud provider selection
- **Manage**: Real-time status checking and data backup
- **Teardown**: Clean infrastructure destruction with evidence preservation

## 🎯 Usage

### **Start New Engagement**
```bash
./engagement-manager.sh start
```
Interactive prompts guide you through:
- Engagement name and client
- Cloud provider selection (AWS/Azure/GCP/All)
- Stealth level (HIGH/MEDIUM/LOW)
- Deployment mode (Primary/Backup)

### **Manage Active Engagement**
```bash
# Check status
./engagement-manager.sh --status

# Stop engagement
./engagement-manager.sh stop

# Backup data
./engagement-manager.sh --backup
```

### **SSL Certificate Management**
```bash
# Setup certificates for deployed services
./setup-ssl.sh outputs/aws_primary.json high
```

### **DNS Failover Configuration**
```bash
# Create DNS configuration
python3 update-dns.py --create-config

# Update DNS records
python3 update-dns.py --provider aws --target azure --all
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    MULTI-CLOUD RED TEAM                 │
├─────────────────────────────────────────────────────────┤
│  Primary (AWS)         Backup (Azure)        Backup (GCP)    │
│  ┌─────────────┐       ┌─────────────┐        ┌─────────────┐ │
│  │   Mythic    │       │   Mythic    │        │   Mythic    │ │
│  │  C2 Server  │       │  C2 Backup  │        │  C2 Backup  │ │
│  └─────────────┘       └─────────────┘        └─────────────┘ │
│  ┌─────────────┐       ┌─────────────┐        ┌─────────────┐ │
│  │   GoPhish   │       │   GoPhish   │        │   GoPhish   │ │
│  │  Phishing   │       │  Phishing   │        │  Phishing   │ │
│  └─────────────┘       └─────────────┘        └─────────────┘ │
│  ┌─────────────┐       ┌─────────────┐        ┌─────────────┐ │
│  │  Evilginx   │       │  Evilginx   │        │  Evilginx   │ │
│  │  Phishing   │       │  Phishing   │        │  Phishing   │ │
│  └─────────────┘       └─────────────┘        └─────────────┘ │
│  ┌─────────────┐       ┌─────────────┐        ┌─────────────┐ │
│  │   Pwndrop   │       │   Pwndrop   │        │   Pwndrop   │ │
│  │ File Server │       │ File Server │        │ File Server │ │
│  └─────────────┘       └─────────────┘        └─────────────┘ │
└─────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │   DNS Failover    │
                    │  (CloudFlare/    │
                    │   Route53/Azure)  │
                    └───────────────────┘
```

## 🔧 Prerequisites

### **Required Tools**
- **Terraform** >= 1.0
- **Python** >= 3.8
- **Cloud CLI Tools**: aws, az, gcloud
- **Docker** and Docker Compose
- **jq** for JSON processing
- **SSH Key Pair** for cloud access

### **Cloud Credentials**
```bash
# AWS
aws configure
aws sts get-caller-identity

# Azure
az login
az account show

# GCP
gcloud auth login
gcloud config list
```

## 📁 Directory Structure

```
multi-cloud-redteam/
├── engagement-manager.sh          # Main engagement lifecycle manager
├── deploy-stealth.sh            # Stealth-enhanced deployment
├── configure-services-stealth.py  # Service configuration
├── setup-ssl.sh                # SSL certificate management
├── update-dns.py                # DNS failover management
├── test-failover.py             # Failover testing
├── generate-terraform-config.py   # Terraform config generator
├── templates/                    # Cloud-init templates
│   ├── cloud-init-mythic.sh
│   ├── cloud-init-gophish.sh
│   ├── cloud-init-evilginx.sh
│   └── cloud-init-pwndrop.sh
├── scripts/                      # Utility scripts
│   ├── configure-multi-operator.sh
│   ├── configure-stealth.sh
│   └── aws-redteam-deploy.sh
├── engagements/                  # Engagement data (created during use)
├── outputs/                      # Terraform outputs
├── logs/                         # Deployment and operation logs
├── ssl-certs/                   # SSL certificates (created during use)
├── monitoring/                   # Monitoring configurations
└── backups/                      # Engagement backups
```

## 🛡️ Stealth Levels

### **HIGH STEALTH** (Recommended for Red Team)
- **Monitoring**: Minimal (Mythic container status only)
- **Evidence**: Distributed across VMs
- **Attack Surface**: Minimal
- **Detection Risk**: LOW

### **MEDIUM STEALTH**
- **Monitoring**: Basic health checks
- **Evidence**: Partially distributed
- **Attack Surface**: Moderate
- **Detection Risk**: MEDIUM

### **LOW STEALTH** (Not Recommended)
- **Monitoring**: Full centralized monitoring
- **Evidence**: Centralized (high risk)
- **Attack Surface**: Large
- **Detection Risk**: HIGH

## 🔐 SSL & Domain Management

### **Obfuscated Domain Generation**
```bash
# Automatic domain obfuscation
Base: example.com
Generated:
- c2-example.com, control-example.com (Mythic)
- phish-example.com, login-example.com (GoPhish)
- proxy-example.com, tunnel-example.com (Evilginx)
- files-example.com, download-example.com (Pwndrop)
```

### **Automated Certificate Setup**
- **Let's Encrypt** integration
- **Auto-renewal** with cron jobs
- **DNS Challenge** for stealth (CloudFlare)
- **Nginx Configuration** with security headers

## 📊 Monitoring & Failover

### **Health Checks**
- Service availability monitoring
- SSL certificate validation
- Resource utilization tracking
- Cross-cloud connectivity

### **Failover Scenarios**
- **Service Failure**: Individual service failover
- **Network Isolation**: Provider-level failover
- **Security Incident**: Immediate full failover

## 🚀 Deployment Examples

### **AWS Test Deployment**
```bash
./engagement-manager.sh start
# Engagement name: test-aws-001
# Client: test-client
# Cloud: aws
# Stealth: high
# Duration: 3
```

### **Azure Production Deployment**
```bash
./engagement-manager.sh start
# Engagement name: client-azure-prod
# Client: production-client
# Cloud: azure
# Stealth: medium
# Duration: 30
```

### **Multi-Cloud Deployment**
```bash
./engagement-manager.sh start
# Cloud: all
# Deploys: AWS primary + Azure/GCP backup
```

## 📖 Documentation

### **Testing Guide**
See [TESTING.md](TESTING.md) for comprehensive testing scenarios and verification steps.

### **Security Considerations**
- **OPSEC Procedures**: Built-in operational security
- **Anti-Forensics**: Evidence minimization and cleanup
- **Access Control**: Multi-operator support with audit logging

### **Cost Optimization**
- **Right-Sizing**: Appropriate instance selection
- **Backup Management**: Cost-effective backup infrastructure
- **Monitoring**: Balanced monitoring vs. cost

## 🔄 CI/CD Integration

### **GitHub Actions Ready**
```yaml
# .github/workflows/deploy.yml
name: Deploy Red Team Infrastructure
on:
  workflow_dispatch:
    inputs:
      cloud_provider:
        required: true
        type: choice
        options: ['aws', 'azure', 'gcp', 'all']
      stealth_level:
        required: true
        type: choice
        options: ['high', 'medium', 'low']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy Infrastructure
        run: |
          ./engagement-manager.sh start
        env:
          CLOUD_PROVIDER: ${{ github.event.inputs.cloud_provider }}
          STEALTH_MODE: ${{ github.event.inputs.stealth_level }}
```

## 🤝 Contributing

1. **Fork** the repository
2. **Create** feature branch
3. **Test** deployment scenarios
4. **Submit** pull request
5. **Document** changes

## 📄 License

This project is for authorized red team operations and security testing purposes only.

---

## 🎯 Quick Deployment Commands

```bash
# Clone and deploy immediately
git clone https://github.com/YOUR_USERNAME/multi-cloud-redteam.git
cd multi-cloud-redteam
./engagement-manager.sh start

# Or deploy directly with environment variables
export CLOUD_PROVIDER=aws
export STEALTH_MODE=high
./deploy-stealth.sh
```

**🚀 Ready for immediate deployment by any red team member!**
