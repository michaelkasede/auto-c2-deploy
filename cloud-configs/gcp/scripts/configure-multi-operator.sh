#!/bin/bash

# Multi-Operator Access Configuration for Red Team Infrastructure
# This script configures secure access for multiple operators

set -euo pipefail

# Configuration
OPERATOR_USERS=${OPERATOR_USERS:-"operator1,operator2,operator3"}
SSH_KEY_DIR=${SSH_KEY_DIR:-"./operator-keys"}
VAULT_PASSWORD_FILE=${VAULT_PASSWORD_FILE:-"./vault-password"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }

# Create operator SSH keys
create_operator_keys() {
    log "Creating SSH keys for operators..."
    
    mkdir -p "$SSH_KEY_DIR"
    
    IFS=',' read -ra USERS <<< "$OPERATOR_USERS"
    for user in "${USERS[@]}"; do
        user=$(echo "$user" | xargs) # trim whitespace
        
        if [[ ! -f "$SSH_KEY_DIR/${user}_id_rsa" ]]; then
            ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_DIR/${user}_id_rsa" -N "" -C "${user}@redteam"
            log "Generated SSH key for $user"
        else
            log "SSH key for $user already exists"
        fi
    done
    
    # Create authorized_keys file
    > "$SSH_KEY_DIR/authorized_keys"
    for user in "${USERS[@]}"; do
        user=$(echo "$user" | xargs)
        cat "$SSH_KEY_DIR/${user}_id_rsa.pub" >> "$SSH_KEY_DIR/authorized_keys"
        echo "# $user" >> "$SSH_KEY_DIR/authorized_keys"
    done
    
    log "Operator SSH keys created"
}

# Configure AWS IAM for operators
configure_aws_iam() {
    log "Configuring AWS IAM for operators..."
    
    # Create IAM policy for operators
    cat > operator-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeImages",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeAddresses",
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:StartInstances",
                "ec2:StopInstances",
                "ec2:RebootInstances"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "us-east-1"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:SendCommand",
                "ssm:DescribeInstanceInformation",
                "ssm:GetCommandInvocation"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    
    # Create IAM role for operators
    aws iam create-role --role-name RedTeamOperator --assume-role-policy-document file://trust-policy.json 2>/dev/null || log "Role already exists"
    aws iam put-role-policy --role-name RedTeamOperator --policy-name RedTeamOperatorPolicy --policy-document file://operator-policy.json
    
    # Create IAM users for operators
    IFS=',' read -ra USERS <<< "$OPERATOR_USERS"
    for user in "${USERS[@]}"; do
        user=$(echo "$user" | xargs)
        
        # Create IAM user
        aws iam create-user --user-name "$user" 2>/dev/null || log "IAM user $user already exists"
        
        # Attach policy
        aws iam attach-user-policy --user-name "$user" --policy-arn arn:aws:iam::aws:policy/RedTeamOperator
        
        # Create access keys
        aws iam create-access-key --user-name "$user" > "$SSH_KEY_DIR/${user}_aws_keys.json" 2>/dev/null || log "AWS keys for $user already exist"
        
        log "Configured AWS IAM for $user"
    done
    
    log "AWS IAM configuration completed"
}

# Configure Mythic for multi-operator access
configure_mythic_users() {
    log "Configuring Mythic for multi-operator access..."
    
    # Get Mythic instance IP
    MYTHIC_IP=$(terraform output -raw mythic_instance_ip 2>/dev/null || echo "")
    
    if [[ -n "$MYTHIC_IP" ]]; then
        # Create Mythic users script
        cat > configure-mythic-users.sh << EOF
#!/bin/bash
# Script to configure Mythic users

cd /opt/mythic

# Start Mythic if not running
sudo ./mythic-cli start

# Wait for Mythic to be ready
sleep 30

# Create operators
EOF
        
        IFS=',' read -ra USERS <<< "$OPERATOR_USERS"
        for user in "${USERS[@]}"; do
            user=$(echo "$user" | xargs)
            echo "echo 'Creating Mythic user: $user'" >> configure-mythic-users.sh
            echo "sudo ./mythic-cli add user --username $user --password \$(openssl rand -base64 16) --role operator" >> configure-mythic-users.sh
        done
        
        chmod +x configure-mythic-users.sh
        
        log "Mythic user configuration script created"
        warn "Run configure-mythic-users.sh on the Mythic instance to create users"
    else
        warn "Mythic instance IP not found. Run after infrastructure deployment."
    fi
}

# Configure shared secrets management
configure_vault() {
    log "Configuring HashiCorp Vault for secrets management..."
    
    # Create Vault configuration
    cat > vault-config.hcl << 'EOF'
ui = true

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

storage "file" {
  path = "/opt/vault/data"
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
EOF
    
    # Create vault startup script
    cat > setup-vault.sh << 'EOF'
#!/bin/bash
# Setup HashiCorp Vault

# Install Vault
wget https://releases.hashicorp.com/vault/1.14.0/vault_1.14.0_linux_amd64.zip
unzip vault_1.14.0_linux_amd64.zip
mv vault /usr/local/bin/
chmod +x /usr/local/bin/vault

# Create vault user
useradd --system --home /opt/vault --shell /bin/bash vault
mkdir -p /opt/vault/data
chown -R vault:vault /opt/vault

# Copy configuration
cp vault-config.hcl /opt/vault/

# Create systemd service
cat > /etc/systemd/system/vault.service << 'EOS'
[Unit]
Description=HashiCorp Vault
Documentation=https://www.vaultproject.io/docs/
After=network.target

[Service]
User=vault
Group=vault
ExecStart=/usr/local/bin/vault server -config=/opt/vault/vault-config.hcl
CapabilityBoundingSet=CAP_IPC_LOCK
AmbientCapabilities=CAP_IPC_LOCK
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOS

systemctl enable vault
systemctl start vault

# Initialize Vault
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init -key-shares=5 -key-threshold=3 > /opt/vault/init.txt

# Unseal Vault (manual step required)
echo "Vault initialized. Unseal keys saved to /opt/vault/init.txt"
echo "Run: vault operator unseal <key1>"
echo "Run: vault operator unseal <key2>" 
echo "Run: vault operator unseal <key3>"
EOF
    
    chmod +x setup-vault.sh
    
    log "Vault configuration created"
    warn "Run setup-vault.sh on a dedicated instance for secrets management"
}

# Configure session management
configure_session_management() {
    log "Configuring session management..."
    
    # Create session management script
    cat > session-manager.sh << 'EOF'
#!/bin/bash
# Session management for operators

SESSION_LOG_DIR="/var/log/redteam-sessions"
mkdir -p "$SESSION_LOG_DIR"

log_session() {
    local user=$1
    local action=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $user: $action" >> "$SESSION_LOG_DIR/sessions.log"
}

# Add to bash profile for session tracking
cat > /etc/profile.d/redteam-session.sh << 'EOS'
export REDTEAM_SESSION_START=$(date '+%Y-%m-%d %H:%M:%S')
export REDTEAM_USER=$(whoami)

log_session_start() {
    echo "[$REDTEAM_SESSION_START] $REDTEAM_USER: Session started" >> /var/log/redteam-sessions/sessions.log
}

log_session_end() {
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$end_time] $REDTEAM_USER: Session ended" >> /var/log/redteam-sessions/sessions.log
}

trap log_session_end EXIT
log_session_start
EOS

chmod +x /etc/profile.d/redteam-session.sh

echo "Session management configured"
echo "Session logs: $SESSION_LOG_DIR/sessions.log"
EOF
    
    chmod +x session-manager.sh
    
    log "Session management configuration created"
}

# Configure audit logging
configure_audit_logging() {
    log "Configuring audit logging..."
    
    # Create audit configuration
    cat > audit-config.json << 'EOF'
{
  "version": 1,
  "disable": false,
  "output_file": "/var/log/redteam-audit.log",
  "output_format": "json",
  "rules": [
    {
      "action": "always",
      "fields": [
        "user",
        "command",
        "timestamp",
        "pwd",
        "ssh_connection"
      ]
    }
  ]
}
EOF
    
    # Create audit script
    cat > setup-audit.sh << 'EOF'
#!/bin/bash
# Setup audit logging

# Install auditd
apt-get update
apt-get install -y auditd

# Configure audit rules
cat > /etc/audit/rules.d/redteam.rules << 'EOR'
-w /opt/mythic/ -p wa -k mythic_operations
-w /opt/gophish/ -p wa -k gophish_operations  
-w /opt/evilginx/ -p wa -k evilginx_operations
-w /opt/pwndrop/ -p wa -k pwndrop_operations
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/sudoers -p wa -k sudo
-w /var/log/ -p wa -k logs
-a always,exit -F arch=b64 -S execve -k command_execution
EOR

# Restart auditd
systemctl restart auditd

# Configure log rotation for audit logs
cat > /etc/logrotate.d/audit << 'EOLR'
/var/log/audit/audit.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
    postrotate
        systemctl reload auditd
    endscript
}
EOLR

echo "Audit logging configured"
echo "Audit logs: /var/log/audit/audit.log"
EOF
    
    chmod +x setup-audit.sh
    
    log "Audit logging configuration created"
}

# Create operator documentation
create_documentation() {
    log "Creating operator documentation..."
    
    cat > REDTEAM_OPERATIONS.md << 'EOF'
# Red Team Operations Guide

## Overview
This guide covers the deployment and operation of red team infrastructure including Mythic, GoPhish, Evilginx, and Pwndrop.

## Access Credentials

### SSH Access
- SSH keys are located in the `operator-keys/` directory
- Each operator has their own key pair: `{operator}_id_rsa` and `{operator}_id_rsa.pub`
- The `authorized_keys` file contains all public keys for deployment

### AWS Access
- AWS credentials are in `{operator}_aws_keys.json`
- These provide limited access to monitoring and basic instance management

### Service Access
- **Mythic**: https://mythic-instance-ip:7443
- **GoPhish Admin**: http://gophish-instance-ip:3333 (VPN/VPC only)
- **Evilginx Admin**: Local access only via SSH tunnel
- **Pwndrop Admin**: Local access only via SSH tunnel

## Security Procedures

### Session Management
- All sessions are logged to `/var/log/redteam-sessions/sessions.log`
- Session start/end times are automatically tracked
- Review logs regularly for unusual activity

### Audit Logging
- Comprehensive audit logging is enabled
- Audit logs are located in `/var/log/audit/audit.log`
- Logs are rotated daily and kept for 30 days

### Secrets Management
- Use HashiCorp Vault for managing sensitive credentials
- Never store passwords in plain text
- Rotate credentials regularly

## Operational Procedures

### Starting Services
```bash
# Mythic
sudo ./mythic-cli start

# GoPhish
cd /opt/gophish && docker-compose up -d

# Evilginx
sudo systemctl start evilginx

# Pwndrop
sudo systemctl start pwndrop
```

### Monitoring
- Check service status: `systemctl status <service>`
- View logs: `journalctl -u <service> -f`
- Health checks run every 5 minutes

### Backup Procedures
- Daily automated backups are configured
- Backup locations:
  - Mythic: `/opt/mythic/backups/`
  - GoPhish: `/opt/gophish/backups/`
  - Evilginx: `/opt/evilginx/backups/`
  - Pwndrop: `/opt/pwndrop/backups/`

### Emergency Procedures
1. **Service Failure**: Check logs and restart service
2. **Security Incident**: Review audit logs and notify team lead
3. **Data Loss**: Restore from latest backup
4. **Compromise**: Isolate affected systems and initiate incident response

## Contact Information
- Team Lead: [contact information]
- Infrastructure Admin: [contact information]
- Security Officer: [contact information]

## Change Management
All configuration changes must be:
1. Documented in change log
2. Approved by team lead
3. Tested in non-production environment
4. Scheduled during maintenance window
EOF
    
    log "Operator documentation created"
}

# Main execution
main() {
    log "Starting multi-operator access configuration..."
    
    create_operator_keys
    configure_aws_iam
    configure_mythic_users
    configure_vault
    configure_session_management
    configure_audit_logging
    create_documentation
    
    log "Multi-operator access configuration completed!"
    
    echo ""
    log "Next steps:"
    echo "1. Distribute SSH keys to operators securely"
    echo "2. Deploy infrastructure and run user configuration scripts"
    echo "3. Configure Vault and distribute unseal keys"
    echo "4. Set up monitoring and alerting"
    echo "5. Conduct operator training"
}

# Run main function
main "$@"
