## Complete AWS red team infrastructure deployment solution created. The setup includes:

## Core Components
- **Mythic C2 Framework** - Automated deployment with SSL configuration
- **GoPhish** - Phishing campaign management with Docker
- **Evilginx** - Advanced phishing with reverse proxy
- **Pwndrop** - Secure file serving with nginx

## Infrastructure Features
- **VPC Architecture** - Public/private subnets with NAT gateways
- **Security Groups** - Least-privilege access with rate limiting
- **IAM Roles** - Multi-operator access with audit logging
- **Monitoring** - CloudWatch integration with health checks

## Security & Stealth
- **Port Knocking** - SSH access protection
- **Application Obfuscation** - Randomized names and ports
- **Anti-Forensics** - Secure deletion and log management
- **OPSEC Procedures** - Pre/post operation checklists

## Deployment Scripts
- [aws-redteam-deploy.sh](cci:7://file:///home/foobar/Mythic/aws-redteam-deploy.sh:0:0-0:0) - Main automation script
- [configure-multi-operator.sh](cci:7://file:///home/foobar/Mythic/configure-multi-operator.sh:0:0-0:0) - User access management
- [configure-stealth.sh](cci:7://file:///home/foobar/Mythic/configure-stealth.sh:0:0-0:0) - Security configurations
- Terraform IaC for infrastructure

## Documentation
- Complete deployment guide
- Operational procedures
- Emergency response plans
- Troubleshooting guides

All scripts are executable and ready for deployment with proper AWS credentials and authorization. The solution supports multiple operators while maintaining stealth and operational security.

You can configure URLs for each service in the following files:

## Service Configuration Files

**Mythic:**
- `/opt/mythic/.env` - After deployment, contains NGINX_BIND_IPV4, NGINX_PORT, etc.
- `/opt/mythic/nginx-docker/config/templates/services.conf.template` - Nginx proxy configuration

**GoPhish:**
- `/opt/gophish/config/config.json` - Contains `listen_url` and proxy settings
- `/opt/gophish/docker-compose.yml` - Port mappings and domain settings

**Evilginx:**
- `/home/evilginx/.evilginx/config.json` - Contains `proxy_domain` and `proxy_addr`
- `/etc/nginx/sites-available/evilginx` - Nginx reverse proxy configuration

**Pwndrop:**
- `/etc/pwndrop/pwndrop.toml` - Server host and port configuration
- `/etc/nginx/sites-available/pwndrop` - Nginx reverse proxy settings

## Infrastructure Level

**Terraform Variables:**
- [variables.tf](cci:7://file:///home/foobar/Mythic/variables.tf:0:0-0:0) - Instance types and basic settings
- [infrastructure.tf](cci:7://file:///home/foobar/Mythic/infrastructure.tf:0:0-0:0) - Security groups and networking

## Quick Reference

For URL changes after deployment, SSH into each instance and modify:

```bash
# Mythic
sudo nano /opt/mythic/.env

# GoPhish
sudo nano /opt/gophish/config/config.json

# Evilginx
sudo nano /home/evilginx/.evilginx/config.json

# Pwndrop
sudo nano /etc/pwndrop/pwndrop.toml
```

Remember to restart the respective services after making changes.