# Multi-Cloud Red Team Infrastructure

This repository provides a complete multi-cloud deployment solution for red team infrastructure, supporting AWS, Azure, and GCP with automated failover capabilities.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Multi-Cloud Red Team                       │
├─────────────────────────────────────────────────────────────────┤
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
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │   DNS Failover    │
                    │  (CloudFlare/    │
                    │   Route53/Azure)  │
                    └───────────────────┘
```

## Features

### Multi-Cloud Support
- **AWS Primary**: Full deployment with all services
- **Azure Backup**: Redundant infrastructure for failover
- **GCP Backup**: Additional redundancy option
- **Automated Failover**: DNS-based failover with health checks

### Services
- **Mythic**: C2 framework for payload management
- **GoPhish**: Phishing campaign management
- **Evilginx**: Advanced phishing with session hijacking
- **Pwndrop**: Secure file serving

### Security & Stealth
- Multi-operator access control
- Stealth configurations
- Anti-forensics measures
- OPSEC procedures

## Quick Start

### Prerequisites
- Terraform >= 1.0
- Python 3.8+
- Cloud CLI tools (aws, az, gcloud)
- Docker and Docker Compose

### Deployment Options

#### 1. Deploy to All Clouds (Recommended)
```bash
# Deploy primary to AWS, backup to Azure and GCP
export CLOUD_PROVIDER=all
./deploy-multi-cloud.sh
```

#### 2. Deploy to Specific Cloud
```bash
# Deploy to AWS only
export CLOUD_PROVIDER=aws
export DEPLOYMENT_MODE=primary
./deploy-multi-cloud.sh

# Deploy backup to Azure
export CLOUD_PROVIDER=azure
export DEPLOYMENT_MODE=backup
./deploy-multi-cloud.sh
```

#### 3. Configure DNS Failover
```bash
# Create DNS configuration
python3 update-dns.py --create-config

# Edit dns-config.json with your domains and API keys
# Then update DNS records
python3 update-dns.py --provider aws --target azure --all
```

#### 4. Test Failover
```bash
# Test all failover scenarios
python3 test-failover.py --scenario all

# Test specific scenario
python3 test-failover.py --scenario service_failure
```

## Configuration Files

### Cloud-Specific Configurations
- `cloud-configs/aws/terraform/` - AWS infrastructure
- `cloud-configs/azure/terraform/` - Azure infrastructure  
- `cloud-configs/gcp/terraform/` - GCP infrastructure

### Service Configuration
- `configure-services.py` - Automated service setup
- `update-dns.py` - DNS failover management
- `test-failover.py` - Failover testing

### Monitoring & Failover
- `failover-config.yaml` - Failover configuration
- `monitoring/cross-cloud-monitor.yaml` - Monitoring setup

## Deployment Modes

### Primary Mode
- Full service deployment
- Active monitoring
- Production configuration
- All operators enabled

### Backup Mode
- Minimal service deployment
- Passive monitoring
- Standby configuration
- Limited operator access

## Failover Scenarios

### Service Failure
- Automatic health checks
- Service-level failover
- DNS updates
- Notification alerts

### Network Isolation
- Connectivity testing
- Provider-level failover
- Traffic rerouting
- SLA monitoring

### Security Incident
- Immediate isolation
- Evidence preservation
- Full infrastructure failover
- Incident response

## DNS Configuration

### Supported Providers
- **CloudFlare**: Recommended for global failover
- **AWS Route53**: Native AWS integration
- **Azure DNS**: Native Azure integration

### Configuration Example
```json
{
  "dns_provider": "cloudflare",
  "services": {
    "mythic": ["mythic.example.com"],
    "gophish": ["phish.example.com"],
    "evilginx": ["evilginx.example.com"],
    "pwndrop": ["files.example.com"]
  },
  "cloudflare": {
    "api_token": "your_api_token",
    "zone_id": "your_zone_id"
  }
}
```

## Monitoring

### Health Checks
- Service availability
- Response time monitoring
- SSL certificate validation
- Resource utilization

### Alerting
- Email notifications
- Slack integration
- PagerDuty alerts
- Custom webhooks

### Logging
- Centralized log aggregation
- Cross-cloud log correlation
- Security event logging
- Performance metrics

## Security Considerations

### Access Control
- Multi-operator support
- Role-based permissions
- SSH key management
- Session logging

### Stealth Measures
- Traffic obfuscation
- Application hiding
- Anti-forensics
- OPSEC procedures

### Data Protection
- Encrypted communications
- Secure key storage
- Data replication
- Backup encryption

## Operational Procedures

### Daily Operations
```bash
# Check service status
python3 check-services.py --all-providers

# Review monitoring alerts
python3 review-alerts.py --last-24h

# Update security configurations
./configure-stealth.sh
```

### Failover Procedures
```bash
# Initiate manual failover
./initiate-failover.sh TARGET_PROVIDER=azure

# Verify failover
python3 verify-failover.py --provider azure

# Update documentation
python3 update-docs.py --failover-event
```

### Recovery Procedures
```bash
# Restore primary provider
./restore-primary.sh --provider aws

# Sync data from backup
python3 sync-data.py --from azure --to aws

# Verify services
python3 verify-services.py --provider aws
```

## Cost Optimization

### Primary Infrastructure
- Use appropriate instance sizes
- Implement auto-scaling
- Monitor resource usage
- Optimize data transfer

### Backup Infrastructure
- Use smaller instances
- Schedule startup/shutdown
- Minimize storage costs
- Optimize backup frequency

### DNS & Monitoring
- Choose cost-effective DNS provider
- Optimize monitoring frequency
- Use alerting wisely
- Review usage regularly

## Troubleshooting

### Common Issues

#### DNS Failover Not Working
```bash
# Check DNS configuration
python3 validate-dns-config.py

# Test DNS updates
python3 test-dns-update.py --domain example.com

# Verify propagation
python3 check-dns-propagation.py --domain example.com
```

#### Service Health Check Failures
```bash
# Test service connectivity
python3 test-service-health.py --provider aws

# Check logs
python3 analyze-logs.py --provider aws --service mythic

# Restart services
python3 restart-services.py --provider aws
```

#### Cloud Provider Issues
```bash
# Validate cloud credentials
python3 validate-credentials.py --provider aws

# Test API access
python3 test-api-access.py --provider aws

# Check quotas
python3 check-quotas.py --provider aws
```

## Emergency Procedures

### Complete AWS Outage
1. **Initiate Full Failover**
   ```bash
   ./initiate-failover.sh TARGET_PROVIDER=azure SERVICE_AFFECTED=all
   ```

2. **Verify All Services**
   ```bash
   python3 verify-all-services.py --provider azure
   ```

3. **Notify Team**
   ```bash
   python3 send-emergency-notification.py --event "aws_outage"
   ```

### Security Incident
1. **Isolate Affected Provider**
   ```bash
   python3 isolate-provider.sh --provider aws
   ```

2. **Preserve Evidence**
   ```bash
   python3 preserve-evidence.py --provider aws
   ```

3. **Failover to Backup**
   ```bash
   ./initiate-failover.sh TARGET_PROVIDER=gcp REASON="security_incident"
   ```

## Documentation

### Generated Reports
- `deployment-report.md` - Deployment summary
- `failover-test-results.md` - Test results
- `security-audit.md` - Security assessment
- `cost-analysis.md` - Cost breakdown

### Operational Guides
- `operator-guide.md` - Daily operations
- `failover-procedures.md` - Failover steps
- `emergency-response.md` - Incident response
- `maintenance-procedures.md` - Maintenance tasks

## Contributing

1. Fork the repository
2. Create feature branch
3. Test multi-cloud deployment
4. Submit pull request
5. Update documentation

## License

This project is for authorized security testing and educational purposes only.

---

**⚠️ WARNING**: This infrastructure is designed for authorized red team operations. Ensure proper authorization before deployment.
