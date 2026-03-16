# Multi-Cloud Red Team Infrastructure - Complete Context & Configuration


This document captures all important context, decisions, and configurations for the multi-cloud red team infrastructure project. Use this as a comprehensive reference when setting up a new workspace.

---

## 🎯 Project Overview

### **Primary Objective**
Create a standalone, stealth-enhanced multi-cloud deployment solution for red team operations with complete engagement lifecycle management.

### **Key Requirements**
- **Standalone**: Completely separate from Mythic installation
- **Multi-Cloud**: AWS (primary), Azure/GCP (backup)
- **Stealth-Enhanced**: Hybrid monitoring approach for operational security
- **Engagement Lifecycle**: Start/stop/manage infrastructure operations
- **Team Deployment**: GitHub repository for collaborative use

---

## 🏗️ Architecture Decisions

### **Service Architecture**
```
VM 1: Mythic Server (t3.large)
├─ Docker Container: Mythic C2
├─ Docker Container: Prometheus (minimal)
├─ Docker Container: Grafana (minimal)
└─ Basic container monitoring only

VM 2: GoPhish Server (t3.medium)
├─ Docker Container: GoPhish
└─ Native SSL/Terminal Access

VM 3: Evilginx Server (t3.medium)
├─ Native Evilginx Installation
└─ Direct Binary Execution

VM 4: Pwndrop Server (t3.small)
├─ Native Pwndrop Installation
└─ Direct File System Access
```

### **Stealth Strategy**
- **HIGH Stealth**: Minimal monitoring (Mythic container only), manual checks for others
- **MEDIUM Stealth**: Basic health checks across services
- **LOW Stealth**: Full monitoring (not recommended for red team)

### **Multi-Cloud Failover**
- **Primary**: AWS with full service deployment
- **Backup**: Azure/GCP with minimal deployment
- **DNS Failover**: CloudFlare/Route53/Azure DNS integration

---

## 📁 Directory Structure

```
multi-cloud-redteam/
├── engagement-manager.sh              # Main engagement lifecycle manager
├── deploy-stealth.sh                # Stealth-enhanced deployment
├── configure-services-stealth.py      # Service configuration with stealth
├── setup-ssl.sh                    # SSL certificate management
├── update-dns.py                    # DNS failover management
├── test-failover.py                 # Failover testing
├── generate-terraform-config.py       # Terraform config generator
├── templates/                        # Cloud-init templates
│   ├── cloud-init-mythic.sh
│   ├── cloud-init-gophish.sh
│   ├── cloud-init-evilginx.sh
│   └── cloud-init-pwndrop.sh
├── scripts/                          # Utility scripts
│   ├── configure-multi-operator.sh
│   ├── configure-stealth.sh
│   └── aws-redteam-deploy.sh
├── engagements/                      # Engagement data (gitignored)
├── outputs/                          # Terraform outputs (gitignored)
├── logs/                             # Deployment and operation logs
├── ssl-certs/                       # SSL certificates (gitignored)
├── monitoring/                       # Monitoring configurations
└── backups/                          # Engagement backups
```

---

## 🔧 Key Files & Configurations

### **Core Deployment Scripts**

#### **engagement-manager.sh**
- **Purpose**: Complete engagement lifecycle management
- **Functions**: start, stop, status, backup, list
- **Features**: Interactive prompts, automatic backup, clean teardown
- **Usage**: `./engagement-manager.sh start`

#### **deploy-stealth.sh**
- **Purpose**: Stealth-enhanced deployment with interactive selection
- **Features**: Cloud provider selection, stealth level configuration
- **Usage**: `./deploy-stealth.sh`

#### **configure-services-stealth.py**
- **Purpose**: Service configuration with stealth considerations
- **Features**: Hybrid monitoring setup, SSL configuration
- **Usage**: `python3 configure-services-stealth.py aws primary outputs.json --stealth high`

#### **setup-ssl.sh**
- **Purpose**: Automated SSL certificate management
- **Features**: Let's Encrypt integration, domain obfuscation, auto-renewal
- **Usage**: `./setup-ssl.sh outputs/aws_primary.json high`

### **Configuration Files**

#### **Stealth Monitoring Configuration**
```yaml
# monitoring/stealth-monitor.yaml
monitoring:
  stealth_level: "high"
  mythic:
    enabled: true
    metrics: ["container_status", "agent_callbacks", "resource_usage"]
    scrape_interval: "5m"
    retention: "7d"
  other_services:
    enabled: false
    monitoring_method: "manual_ssh"
  evidence_handling:
    distribution: "distributed"
    encryption: true
    auto_cleanup: true
```

#### **DNS Configuration Template**
```json
{
  "dns_provider": "cloudflare",
  "services": {
    "mythic": ["c2-example.com", "control-example.com"],
    "gophish": ["phish-example.com", "login-example.com"],
    "evilginx": ["proxy-example.com", "tunnel-example.com"],
    "pwndrop": ["files-example.com", "download-example.com"]
  }
}
```

---

## 🛡️ Security & Stealth Configurations

### **Domain Obfuscation Strategy**
```bash
# Base domain: example.com
# Generated obfuscated domains:
Mythic: c2-example.com, control-example.com
GoPhish: phish-example.com, login-example.com
Evilginx: proxy-example.com, tunnel-example.com
Pwndrop: files-example.com, download-example.com
```

### **SSL Certificate Management**
- **Provider**: Let's Encrypt
- **Challenge Type**: DNS (high stealth) or HTTP (medium stealth)
- **Auto-renewal**: Cron job at 12:00 daily
- **Security Headers**: HSTS, X-Frame-Options, CSP

### **Monitoring by Stealth Level**

#### **HIGH STEALTH**
- Mythic: Container status only (5m intervals)
- Other services: Manual SSH checks
- Evidence: Distributed across VMs
- Attack surface: Minimal

#### **MEDIUM STEALTH**
- Mythic: Basic health checks (3m intervals)
- Other services: Local node exporters
- Evidence: Partially distributed
- Attack surface: Moderate

#### **LOW STEALTH**
- All services: Full Prometheus/Grafana
- Evidence: Centralized (high risk)
- Attack surface: Large
- Not recommended for red team

---

## 🚀 Deployment Workflows

### **Standard Engagement Workflow**
```bash
# 1. Start new engagement
./engagement-manager.sh start

# 2. Follow prompts:
# - Engagement name: client-2024-03
# - Client name: client-name
# - Duration: 7
# - Cloud provider: aws
# - Stealth level: high
# - Deployment mode: primary

# 3. Setup SSL certificates
./setup-ssl.sh outputs/aws_primary.json high

# 4. Configure DNS failover
python3 update-dns.py --create-config
# Edit dns-config.json
python3 update-dns.py --provider aws --target azure --all

# 5. Check status
./engagement-manager.sh --status

# 6. Stop engagement when done
./engagement-manager.sh stop
```

### **Multi-Cloud Deployment Workflow**
```bash
# 1. Start multi-cloud engagement
./engagement-manager.sh start
# Select "all" for cloud provider

# 2. This deploys:
# - AWS: Primary deployment (all services)
# - Azure: Backup deployment (minimal)
# - GCP: Backup deployment (minimal)

# 3. Configure failover
python3 update-dns.py --create-config
python3 update-dns.py --all
```

### **Testing Workflow**
```bash
# 1. Test single cloud
./engagement-manager.sh start
# Select aws, duration: 1, stealth: high

# 2. Verify deployment
./engagement-manager.sh --status
cat engagements/test-aws-001/deployment.json

# 3. Test SSL
./setup-ssl.sh engagements/test-aws-001/deployment.json high

# 4. Test failover
python3 test-failover.py --scenario service_failure

# 5. Clean up
./engagement-manager.sh stop
```

---

## 🔐 Security Considerations

### **Operational Security (OPSEC)**
- **VPN Required**: All management access through VPN
- **SSH Key Rotation**: Regular key updates
- **Log Management**: Auto-cleanup and rotation
- **Evidence Distribution**: Minimize centralization

### **Anti-Forensics**
- **Log Rotation**: 7-day retention for high stealth
- **Data Cleanup**: Automatic cleanup scripts
- **Process Hiding**: Use Docker for process obfuscation
- **Network Obfuscation**: Domain obfuscation and SSL

### **Access Control**
- **Multi-Operator Support**: Role-based permissions
- **Session Logging**: All management sessions logged
- **Audit Trail**: Complete deployment history
- **Credential Management**: No credentials in repository

---

## 📊 Performance Benchmarks

### **Deployment Times**
- **AWS**: 15-25 minutes
- **Azure**: 20-30 minutes
- **GCP**: 18-28 minutes
- **Multi-Cloud**: 45-60 minutes

### **Resource Requirements**
- **Mythic VM**: 2-4 GB RAM, 2 vCPU, t3.large
- **GoPhish VM**: 1-2 GB RAM, 1 vCPU, t3.medium
- **Evilginx VM**: 1-2 GB RAM, 1 vCPU, t3.medium
- **Pwndrop VM**: 0.5-1 GB RAM, 1 vCPU, t3.small

### **Cost Estimates (Monthly)**
- **AWS Primary**: $300-400
- **Azure Backup**: $150-200
- **GCP Backup**: $150-200
- **Total Multi-Cloud**: $600-800

---

## 🔄 GitHub Repository Setup

### **Repository Structure**
```
multi-cloud-redteam/
├── .github/workflows/deploy.yml     # CI/CD automation
├── GITHUB_README.md               # Repository overview
├── GITHUB_SETUP.md                # Team setup guide
├── engagement-manager.sh            # Main lifecycle manager
└── [all other project files]
```

### **Team Deployment**
```bash
# 1. Clone repository
git clone https://github.com/YOUR_USERNAME/multi-cloud-redteam.git
cd multi-cloud-redteam

# 2. Deploy immediately
./engagement-manager.sh start

# 3. Or use GitHub Actions
# Visit repository > Actions > Deploy Red Team Infrastructure
# Select parameters and run workflow
```

### **Security Settings**
- **Private Repository**: Keep red team tools private
- **Two-Factor Auth**: Required for all team members
- **Branch Protection**: Require PR reviews for main branch
- **No Credentials**: Never commit sensitive data

---

## 🚨 Critical Decisions & Rationale

### **Decision 1: Hybrid Monitoring Approach**
**Problem**: Full monitoring creates evidence, no monitoring reduces operational visibility
**Solution**: Hybrid approach with stealth levels
**Rationale**: Balances operational needs with stealth requirements

### **Decision 2: Standalone Deployment**
**Problem**: Integration with Mythic creates complexity and dependencies
**Solution**: Complete separation in multi-cloud-redteam directory
**Rationale**: Simplifies deployment, reduces dependencies, improves portability

### **Decision 3: Engagement Lifecycle Management**
**Problem**: Infrastructure deployment without proper lifecycle management
**Solution**: engagement-manager.sh with start/stop/status/backup
**Rationale**: Professional red team operations require proper engagement management

### **Decision 4: Domain Obfuscation**
**Problem**: Obvious domain names trigger defenses
**Solution**: Automated generation of defense-evading domains
**Rationale**: Reduces detection risk while maintaining operational capability

### **Decision 5: Multi-Cloud Architecture**
**Problem**: Single cloud provider creates single point of failure
**Solution**: Primary deployment on AWS, backup on Azure/GCP
**Rationale**: Provides redundancy and failover capabilities

---

## 📋 Prerequisites & Dependencies

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

### **System Requirements**
- **RAM**: 8GB minimum for local operations
- **Storage**: 10GB free space
- **Network**: Stable internet connection
- **OS**: Linux/macOS (Windows WSL supported)

---

## 🔧 Troubleshooting Guide

### **Common Issues**

#### **Deployment Fails**
```bash
# Check cloud credentials
aws sts get-caller-identity    # AWS
az account show               # Azure
gcloud auth list              # GCP

# Check Terraform state
ls -la cloud-configs/aws/terraform/
cat cloud-configs/aws/terraform/terraform.tfstate

# Check logs
tail -f logs/deployment_*.log
```

#### **SSL Certificate Issues**
```bash
# Check certbot installation
ssh ubuntu@<IP> "certbot --version"

# Check certificate status
ssh ubuntu@<IP> "certbot certificates"

# Check nginx configuration
ssh ubuntu@<IP> "nginx -t"
```

#### **Service Access Issues**
```bash
# Check service status
./engagement-manager.sh --status

# Test connectivity
nmap -p 443,7443,8080 <IP>

# Check logs
ssh ubuntu@<IP> "docker logs <container_name>"
```

### **Performance Issues**
- **Slow Deployment**: Check cloud provider quotas
- **High Costs**: Review instance sizes and duration
- **SSL Delays**: Use DNS challenge for stealth

---

## 📈 Future Enhancements

### **Planned Features**
1. **Automated Cost Monitoring**: Real-time cost tracking and alerts
2. **Advanced Threat Simulation**: Built-in attack simulation capabilities
3. **Enhanced Reporting**: Automated engagement reports
4. **Mobile Management**: Mobile app for engagement management
5. **Integration APIs**: REST APIs for external tool integration

### **Potential Improvements**
1. **Container Optimization**: Reduce container sizes and startup times
2. **Network Hardening**: Advanced network segmentation and encryption
3. **Automation**: More automated configuration and management
4. **Scalability**: Support for larger team deployments
5. **Compliance**: Built-in compliance checking and reporting

---

## 🎯 Quick Start Commands

### **Immediate Deployment**
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

### **Testing Commands**
```bash
# Test AWS deployment
./engagement-manager.sh start
# Select: test-aws-001, test-client, 1, aws, high, primary

# Test multi-cloud
./engagement-manager.sh start
# Select: test-multicloud-001, test-client, 1, all, high, primary

# Verify deployment
./engagement-manager.sh --status
cat engagements/test-*/deployment.json
```

### **Management Commands**
```bash
# Check all engagements
./engagement-manager.sh list

# Backup current engagement
./engagement-manager.sh --backup

# Stop engagement
./engagement-manager.sh stop
```

---

## 📚 Key Learning Points

### **Technical Learnings**
1. **Hybrid Monitoring**: Balance stealth vs. operational visibility
2. **Multi-Cloud Architecture**: Primary/backup deployment patterns
3. **Engagement Lifecycle**: Professional red team operations management
4. **Domain Obfuscation**: Automated defense evasion techniques
5. **SSL Automation**: Let's Encrypt integration for red team tools

### **Operational Learnings**
1. **Team Deployment**: GitHub repository for collaborative operations
2. **Security Best Practices**: OPSEC and anti-forensics implementation
3. **Cost Management**: Multi-cloud cost optimization strategies
4. **Automation**: Reduce manual deployment and management overhead
5. **Documentation**: Comprehensive documentation for team knowledge sharing

---

## 🚀 Final Status

**Project Status**: ✅ **COMPLETE AND READY FOR PRODUCTION**

**Key Achievements**:
- ✅ Standalone multi-cloud deployment system
- ✅ Stealth-enhanced configurations with hybrid monitoring
- ✅ Complete engagement lifecycle management
- ✅ GitHub repository ready for team collaboration
- ✅ Comprehensive documentation and testing guides
- ✅ Automated SSL certificate management
- ✅ Domain obfuscation for defense evasion
- ✅ Multi-cloud failover capabilities

**Ready For**: 
- Immediate deployment by red team members
- GitHub repository transfer and team collaboration
- Production red team operations
- Engagement lifecycle management
- Multi-cloud infrastructure deployment

---

**🎯 This document provides complete context for recreating the multi-cloud red team infrastructure in any new workspace.**
