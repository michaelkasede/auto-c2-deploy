# AWS Red Team Infrastructure Deployment

This repository contains the complete infrastructure and configuration for deploying a stealthy, multi-operator red team environment on AWS with Mythic, GoPhish, Evilginx, and Pwndrop.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS VPC (10.0.0.0/16)                    │
├─────────────────────────────────────────────────────────────┤
│  Public Subnets (10.0.1.0/24, 10.0.2.0/24)                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │   Mythic    │ │   GoPhish   │ │  Evilginx   │           │
│  │  C2 Server  │ │  Phishing   │ │  Phishing   │           │
│  │   (t3.large)│ │  (t3.medium)│ │ (t3.medium) │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
│  ┌─────────────┐                                           │
│  │   Pwndrop   │                                           │
│  │ File Server │                                           │
│  │ (t3.small)  │                                           │
│  └─────────────┘                                           │
├─────────────────────────────────────────────────────────────┤
│  Private Subnets (10.0.10.0/24, 10.0.20.0/24)               │
│  ┌─────────────┐ ┌─────────────┐                           │
│  │   Database  │ │   Monitoring│                           │
│  │   Services  │ │   & Logging │                           │
│  └─────────────┘ └─────────────┘                           │
└─────────────────────────────────────────────────────────────┘
```

## Services

- **Mythic**: Cross-platform C2 framework for payload management and operator collaboration
- **GoPhish**: Phishing campaign management and credential harvesting
- **Evilginx**: Advanced phishing framework with session hijacking
- **Pwndrop**: Secure file serving for payload delivery

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Docker and Docker Compose
- SSH key pair for initial access

### Deployment

1. **Clone and prepare:**
```bash
git clone <repository-url>
cd aws-redteam-infrastructure
chmod +x *.sh
```

2. **Configure environment:**
```bash
export AWS_REGION="us-east-1"
export SSH_KEY_NAME="redteam-key"
export ADMIN_IP=$(curl -s ifconfig.me)
```

3. **Deploy infrastructure:**
```bash
./aws-redteam-deploy.sh
```

4. **Configure multi-operator access:**
```bash
./configure-multi-operator.sh
```

5. **Apply stealth configurations:**
```bash
./configure-stealth.sh
```

## Configuration Files

### Infrastructure as Code

- `infrastructure.tf` - Main Terraform configuration
- `variables.tf` - Terraform variables
- `cloud-init-*.sh` - Instance initialization scripts

### Deployment Scripts

- `aws-redteam-deploy.sh` - Main deployment automation
- `configure-multi-operator.sh` - Multi-operator access setup
- `configure-stealth.sh` - Security and stealth configurations

## Security Features

### Network Security
- VPC with public/private subnets
- Security groups with least-privilege access
- NAT gateways for outbound internet access
- Rate limiting and DDoS protection

### Access Control
- SSH key-based authentication
- IAM roles for operators
- Multi-factor authentication support
- Session management and audit logging

### Stealth Measures
- Port knocking for SSH access
- Application obfuscation
- Anti-forensics capabilities
- Traffic shaping and obfuscation

### Monitoring
- CloudWatch integration
- Centralized logging
- Health checks and alerts
- Automated backup systems

## Operational Procedures

### Service Management

```bash
# Start all services
./aws-redteam-deploy.sh

# Check service status
systemctl status mythic
systemctl status gophish
systemctl status evilginx
systemctl status pwndrop
```

### User Management

```bash
# Add new operator
./configure-multi-operator.sh OPERATOR_USERS="newuser"

# Rotate credentials
./configure-stealth.sh STEALTH_LEVEL="high"
```

### Backup and Recovery

```bash
# Manual backup
./backup-all-services.sh

# Restore from backup
./restore-all-services.sh <backup-date>
```

## Access Information

After deployment, access credentials will be available in:

- SSH keys: `./operator-keys/`
- AWS credentials: `./operator-keys/{user}_aws_keys.json`
- Service passwords: Check respective service logs

### Service URLs

- **Mythic**: `https://<mythic-ip>:7443`
- **GoPhish Admin**: `http://<gophish-ip>:3333` (VPN/VPC only)
- **Evilginx**: SSH tunnel to port 8080
- **Pwndrop**: SSH tunnel to port 8080

## Stealth Configuration Levels

### Low Stealth
- Basic security hardening
- Standard logging
- Minimal obfuscation

### Medium Stealth (Recommended)
- Network traffic obfuscation
- Application-level hiding
- Anti-forensics measures
- OPSEC procedures

### High Stealth
- Advanced traffic shaping
- Domain fronting
- Custom protocols
- Minimal logging

## Monitoring and Alerting

### Health Checks
- Automated service health monitoring
- Resource usage alerts
- SSL certificate expiration alerts

### Security Monitoring
- Authentication failure alerts
- Unusual access pattern detection
- File integrity monitoring

### Operational Monitoring
- Session logging
- Command execution auditing
- Change management tracking

## Emergency Procedures

### Compromise Response
1. Immediate service isolation
2. Key rotation
3. Credential reset
4. Forensic analysis
5. Team notification

### Service Recovery
1. Restore from backup
2. Verify integrity
3. Update configurations
4. Resume operations

## Cost Optimization

- Use spot instances for non-critical services
- Implement auto-scaling where possible
- Regular cleanup of unused resources
- Monitor and optimize data transfer costs

## Compliance Considerations

- Ensure authorization for all activities
- Maintain audit trails
- Follow data protection regulations
- Document all security measures

## Troubleshooting

### Common Issues

1. **SSH Access Issues**
   - Verify IP in security group
   - Check SSH key permissions
   - Verify port knocking sequence

2. **Service Startup Failures**
   - Check system logs: `journalctl -u <service>`
   - Verify Docker status
   - Check resource availability

3. **SSL Certificate Issues**
   - Verify certificate paths
   - Check expiration dates
   - Validate certificate chains

## Support and Documentation

- **Mythic Documentation**: https://docs.mythic-c2.net
- **GoPhish Documentation**: https://getgophish.com/documentation
- **Evilginx Documentation**: https://github.com/kgretzky/evilginx2
- **Pwndrop Documentation**: https://github.com/kgretzky/pwndrop

## Change Log

### v1.0.0
- Initial deployment configuration
- Multi-operator support
- Stealth measures implementation
- Automated backup systems

## Contributing

1. Fork the repository
2. Create feature branch
3. Submit pull request
4. Ensure all tests pass

## License

This project is for authorized security testing and educational purposes only. Users are responsible for ensuring compliance with all applicable laws and regulations.

---

**⚠️ WARNING**: This infrastructure is designed for authorized red team operations only. Ensure proper authorization before deployment and operation.
