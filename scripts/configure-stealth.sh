#!/bin/bash

# Stealth and Operational Security Configuration
# This script implements stealth measures and operational security controls

set -euo pipefail

# Configuration
STEALTH_LEVEL=${STEALTH_LEVEL:-"medium"}  # low, medium, high
LOG_LEVEL=${LOG_LEVEL:-"minimal"}  # minimal, standard, verbose
OBFUSCATION_ENABLED=${OBFUSCATION_ENABLED:-"true"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }

# Configure network stealth
configure_network_stealth() {
    log "Configuring network stealth measures..."
    
    # Create iptables rules for stealth
    cat > iptables-stealth.sh << 'EOF'
#!/bin/bash
# Network stealth configuration

# Clear existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established/related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Stealth port knocking (example for SSH)
# Port sequence: 1000 -> 2000 -> 3000 -> SSH
iptables -N SSH_KNOCK
iptables -A SSH_KNOCK -m recent --rcheck --seconds 30 --name KNOCK3 --rsource -m recent --remove --name KNOCK3 --rsource -j ACCEPT
iptables -A SSH_KNOCK -m recent --rcheck --seconds 10 --name KNOCK2 --rsource -m recent --set --name KNOCK3 --rsource -j DROP
iptables -A SSH_KNOCK -m recent --rcheck --seconds 10 --name KNOCK1 --rsource -m recent --set --name KNOCK2 --rsource -j DROP
iptables -A SSH_KNOCK -m recent --set --name KNOCK1 --rsource -j DROP

# Port knocking rules
iptables -A INPUT -p tcp --dport 1000 -m recent --set --name KNOCK1 --rsource -j LOG --log-prefix "KNOCK1: "
iptables -A INPUT -p tcp --dport 2000 -m recent --rcheck --name KNOCK1 --rsource -m recent --set --name KNOCK2 --rsource -j LOG --log-prefix "KNOCK2: "
iptables -A INPUT -p tcp --dport 3000 -m recent --rcheck --name KNOCK2 --rsource -m recent --set --name KNOCK3 --rsource -j LOG --log-prefix "KNOCK3: "
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j SSH_KNOCK

# Allow legitimate services (with rate limiting)
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 50/min --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m limit --limit 50/min --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 7443 -m conntrack --ctstate NEW -m limit --limit 20/min --limit-burst 40 -j ACCEPT

# Block common scanning tools
iptables -A INPUT -m string --string "nmap" --algo bm -j DROP
iptables -A INPUT -m string --string "masscan" --algo bm -j DROP
iptables -A INPUT -m string --string "nikto" --algo bm -j DROP

# Stealth logging (only log suspicious activity)
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "STEALTH-DROP: " --log-level 4

# Save rules
iptables-save > /etc/iptables/rules.v4
EOF
    
    chmod +x iptables-stealth.sh
    
    log "Network stealth configuration created"
}

# Configure application-level stealth
configure_application_stealth() {
    log "Configuring application-level stealth..."
    
    # Nginx stealth configuration
    cat > nginx-stealth.conf << 'EOF'
# Nginx stealth configuration

# Hide server tokens
server_tokens off;

# Custom server headers to blend in
more_set_headers "Server: Apache/2.4.41 (Ubuntu)";
more_set_headers "X-Powered-By: PHP/7.4.3";
more_set_headers "X-Generator: WordPress 5.8";

# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

# Block suspicious user agents
map $http_user_agent $blocked_agent {
    default 0;
    ~*nmap 1;
    ~*masscan 1;
    ~*nikto 1;
    ~*sqlmap 1;
    ~*dirb 1;
    ~*gobuster 1;
    ~*wfuzz 1;
    ~*burp 1;
}

# Block common exploit paths
location ~* \.(asp|aspx|jsp|cgi|php)$ {
    deny all;
    return 404;
}

location ~* \.(exe|bat|cmd|scr|pif|com)$ {
    deny all;
    return 404;
}

# Hide admin interfaces
location ~* /(admin|administrator|wp-admin|wp-login|phpmyadmin) {
    deny all;
    return 404;
}

# Custom error pages that look normal
error_page 404 /404.html;
error_page 403 /403.html;
error_page 500 /500.html;
EOF
    
    # Application obfuscation
    cat > app-obfuscation.sh << 'EOF'
#!/bin/bash
# Application obfuscation

# Randomize container names
docker rename mythic_nginx_1 "web-$(openssl rand -hex 6)"
docker rename mythic_server_1 "api-$(openssl rand -hex 6)"
docker rename mythic_react_1 "ui-$(openssl rand -hex 6)"

# Change default ports
sed -i 's/7443/8443/g' /opt/mythic/.env
sed -i 's/3333/4444/g' /opt/gophish/config/config.json
sed -i 's/8080/9090/g' /etc/pwndrop/pwndrop.toml

# Obfuscate service banners
echo "Apache/2.4.41 (Ubuntu)" > /etc/hostname
hostnamectl set-hostname "web-server-$(openssl rand -hex 4)"

# Remove version information from applications
find /opt -name "*.py" -exec sed -i 's/version.*=.*\"[0-9.]*\"/version=\"1.0.0\"/g' {} \;
find /opt -name "*.js" -exec sed -i 's/version.*:.*\"[0-9.]*\"/version:\"1.0.0\"/g' {} \;
EOF
    
    chmod +x app-obfuscation.sh
    
    log "Application stealth configuration created"
}

# Configure anti-forensics
configure_antiforensics() {
    log "Configuring anti-forensics measures..."
    
    cat > antiforensics.sh << 'EOF'
#!/bin/bash
# Anti-forensics configuration

# Secure delete files
sdelete() {
    local file="$1"
    shred -vfz -n 3 "$file"
    sync
}

# Clear system logs periodically
clear_logs() {
    # Clear sensitive logs but keep security logs
    > /var/log/auth.log
    > /var/log/syslog
    > /var/log/kern.log
    > /var/log/dmesg
    
    # Clear bash history
    > ~/.bash_history
    history -c
    
    # Clear temporary files
    find /tmp -type f -mtime +1 -delete
    find /var/tmp -type f -mtime +1 -delete
    
    # Clear memory caches
    sync
    echo 3 > /proc/sys/vm/drop_caches
}

# Encrypt sensitive data
encrypt_data() {
    local data_dir="$1"
    local passphrase="$2"
    
    find "$data_dir" -type f -name "*.log" -exec openssl enc -aes-256-cbc -salt -in {} -out {}.enc -pass pass:"$passphrase" -a \;
    find "$data_dir" -type f -name "*.log" -delete
}

# Add cron jobs for periodic cleanup
echo "0 */6 * * * /opt/scripts/clear_logs" | crontab -
echo "0 2 * * * /opt/scripts/encrypt_data /opt/mythic/logs \"$(openssl rand -hex 16)\"" | crontab -

# Configure secure deletion
echo "alias rm='shred -vfz -n 3'" >> ~/.bashrc
echo "alias shred='shred -vfz -n 7'" >> ~/.bashrc

# Disable core dumps
echo "* hard core 0" >> /etc/security/limits.conf
echo "kernel.core_pattern=|/bin/false" >> /etc/sysctl.conf

# Zero free space (run periodically)
zero_free_space() {
    local dir="$1"
    dd if=/dev/zero of="$dir/zero.file" bs=1M status=progress || true
    rm -f "$dir/zero.file"
}
EOF
    
    chmod +x antiforensics.sh
    
    log "Anti-forensics configuration created"
}

# Configure monitoring evasion
configure_monitoring_evasion() {
    log "Configuring monitoring evasion..."
    
    cat > monitoring-evasion.sh << 'EOF'
#!/bin/bash
# Monitoring evasion techniques

# Randomize timing of operations
random_delay() {
    local max_delay="$1"
    local delay=$(($RANDOM % max_delay))
    sleep $delay
}

# Distribute traffic across multiple IPs
rotate_ips() {
    local ips=("52.52.52.52" "53.53.53.53" "54.54.54.54")
    local random_ip=${ips[$RANDOM % ${#ips[@]}]}
    echo "$random_ip"
}

# Obfuscate traffic patterns
traffic_obfuscation() {
    # Add random padding to packets
    tc qdisc add dev eth0 root netq delay 10ms 5ms
    
    # Randomize packet timing
    for i in {1..100}; do
        random_delay 5
        ping -c 1 8.8.8.8 >/dev/null 2>&1 &
    done
}

# Hide from common security tools
hide_from_tools() {
    # Block common security scanner IPs
    iptables -A INPUT -s 192.168.1.0/24 -j DROP  # Example internal network
    
    # Serve fake content to scanners
    echo "This site is under construction" > /var/www/html/index.html
    
    # Create decoy services
    nc -l -k -p 8080 -e echo "HTTP/1.1 200 OK\r\n\r\n decoy" &
}

# Implement domain fronting if needed
domain_fronting() {
    # Configure nginx to use CDN as front
    cat > /etc/nginx/sites-available/domain-fronting << 'EOF'
server {
    listen 80;
    server_name legitimate-cdn-domain.com;
    
    location /hidden-path/ {
        proxy_pass http://127.0.0.1:7443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
}
EOF
    
    chmod +x monitoring-evasion.sh
    
    log "Monitoring evasion configuration created"
}

# Configure operational security procedures
configure_opsec() {
    log "Configuring operational security procedures..."
    
    cat > opsec-procedures.sh << 'EOF'
#!/bin/bash
# Operational security procedures

# Pre-operation checklist
pre_op_check() {
    echo "=== PRE-OPERATION CHECKLIST ==="
    
    # Verify all services are running
    systemctl status mythic | grep -q "active (running)" || echo "WARNING: Mythic not running"
    systemctl status gophish | grep -q "active (running)" || echo "WARNING: GoPhish not running"
    systemctl status evilginx | grep -q "active (running)" || echo "WARNING: Evilginx not running"
    systemctl status pwndrop | grep -q "active (running)" || echo "WARNING: Pwndrop not running"
    
    # Check for exposed credentials
    find /opt -name "*.conf" -o -name "*.env" -o -name "*.key" | while read file; do
        if grep -q "password\|secret\|key" "$file" 2>/dev/null; then
            echo "WARNING: Potential credentials in $file"
        fi
    done
    
    # Verify SSL certificates
    for cert in /etc/ssl/certs/*.crt; do
        if openssl x509 -in "$cert" -noout -checkend 86400 2>/dev/null; then
            echo "OK: $cert valid"
        else
            echo "WARNING: $cert expired or expiring soon"
        fi
    done
    
    # Check audit logging
    if [[ ! -f /var/log/audit/audit.log ]]; then
        echo "WARNING: Audit logging not configured"
    fi
    
    echo "=== CHECKLIST COMPLETE ==="
}

# Post-operation cleanup
post_op_cleanup() {
    echo "=== POST-OPERATION CLEANUP ==="
    
    # Clear operation logs
    find /var/log -name "*operation*" -delete
    
    # Clear browser history (if applicable)
    > ~/.mozilla/firefox/*/places.sqlite 2>/dev/null || true
    
    # Clear temp files
    find /tmp -name "*payload*" -delete
    find /tmp -name "*malware*" -delete
    
    # Rotate keys if compromised
    if [[ "$1" == "compromise" ]]; then
        echo "CRITICAL: Potential compromise detected"
        echo "Initiating key rotation and service restart"
        
        # Generate new SSL keys
        openssl genrsa -out /etc/ssl/private/new.key 4096
        openssl req -new -x509 -key /etc/ssl/private/new.key -out /etc/ssl/certs/new.crt -days 365
        
        # Restart services with new keys
        systemctl restart nginx
        systemctl restart mythic
    fi
    
    echo "=== CLEANUP COMPLETE ==="
}

# Continuous monitoring
continuous_monitoring() {
    while true; do
        # Check for unusual activity
        if journalctl --since "1 hour ago" | grep -q "authentication failure"; then
            echo "WARNING: Authentication failures detected"
        fi
        
        # Check for resource exhaustion
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        if (( $(echo "$cpu_usage > 80" | bc -l) )); then
            echo "WARNING: High CPU usage: $cpu_usage%"
        fi
        
        # Check disk space
        disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
        if [[ $disk_usage -gt 80 ]]; then
            echo "WARNING: High disk usage: $disk_usage%"
        fi
        
        sleep 300  # Check every 5 minutes
    done
}

# Add to cron for automated checks
echo "*/15 * * * * /opt/scripts/pre_op_check >> /var/log/opsec-checks.log 2>&1" | crontab -
EOF
    
    chmod +x opsec-procedures.sh
    
    log "OPSEC procedures configured"
}

# Create stealth documentation
create_stealth_docs() {
    log "Creating stealth documentation..."
    
    cat > STEALTH_GUIDE.md << 'EOF'
# Red Team Stealth Operations Guide

## Overview
This guide covers stealth measures and operational security procedures for red team infrastructure.

## Stealth Levels

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

## Network Stealth

### Port Knocking
SSH access requires port knocking sequence:
1. Port 1000
2. Port 2000  
3. Port 3000
4. Port 22 (SSH)

### Rate Limiting
- HTTP: 50 requests/minute
- HTTPS: 50 requests/minute
- API: 10 requests/second
- Login: 1 request/second

### Traffic Obfuscation
- Random packet delays
- Traffic padding
- IP rotation (if configured)

## Application Stealth

### Service Obfuscation
- Randomized container names
- Changed default ports
- Fake server banners
- Hidden admin interfaces

### SSL Certificate Management
- Use legitimate-looking certificates
- Rotate certificates regularly
- Consider domain fronting

## Anti-Forensics

### Log Management
- Clear sensitive logs periodically
- Encrypt operation logs
- Maintain security logs only

### Data Protection
- Secure file deletion
- Memory clearing
- Temporary file cleanup

## Operational Security

### Pre-Operation Checklist
- Verify service status
- Check for exposed credentials
- Validate SSL certificates
- Confirm audit logging

### Post-Operation Cleanup
- Clear operation logs
- Remove temporary files
- Rotate keys if compromised

### Continuous Monitoring
- Authentication failure alerts
- Resource usage monitoring
- Disk space monitoring

## Emergency Procedures

### Compromise Detection
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

## Best Practices

1. **Need-to-Know**: Limit access to sensitive information
2. **Least Privilege**: Use minimal necessary permissions
3. **Regular Rotation**: Rotate keys and credentials
4. **Documentation**: Maintain clear operation logs
5. **Testing**: Regularly test stealth measures

## Contact Information
- Security Officer: [contact]
- Infrastructure Admin: [contact]
- Team Lead: [contact]
EOF
    
    log "Stealth documentation created"
}

# Main execution
main() {
    log "Starting stealth and operational security configuration..."
    
    configure_network_stealth
    configure_application_stealth
    configure_antiforensics
    configure_monitoring_evasion
    configure_opsec
    create_stealth_docs
    
    log "Stealth and OPSEC configuration completed!"
    
    echo ""
    log "Stealth level: $STEALTH_LEVEL"
    log "Log level: $LOG_LEVEL"
    log "Obfuscation: $OBFUSCATION_ENABLED"
    
    echo ""
    warn "Review and customize configurations before deployment"
    warn "Test all stealth measures in a controlled environment"
    warn "Regularly update and rotate security measures"
}

# Run main function
main "$@"
