#!/bin/bash

# SSL Certificate Setup for Multi-Cloud Red Team Infrastructure
# Automated Let's Encrypt certificate generation and management

set -euo pipefail

# Configuration
DOMAINS_FILE="$1"
STEALTH_MODE="${2:-high}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }
header() { echo -e "${CYAN}=== $1 ===${NC}"; }

# Obfuscated domain generator
generate_obfuscated_domains() {
    local base_domain="$1"
    local service="$2"
    
    case "$service" in
        mythic)
            echo "c2-${base_domain} control-${base_domain} command-${base_domain}"
            ;;
        gophish)
            echo "phish-${base_domain} login-${base_domain} auth-${base_domain}"
            ;;
        evilginx)
            echo "proxy-${base_domain} tunnel-${base_domain} gateway-${base_domain}"
            ;;
        pwndrop)
            echo "files-${base_domain} download-${base_domain} assets-${base_domain}"
            ;;
        *)
            echo "${service}-${base_domain}"
            ;;
    esac
}

# Setup SSL certificates for a service
setup_service_ssl() {
    local ip="$1"
    local service="$2"
    local domain="$3"
    
    log "Setting up SSL certificates for ${service} on ${ip} (${domain})"
    
    # Create SSL directory structure
    ssh -i ~/.ssh/redteam-key -o StrictHostKeyChecking=no ubuntu@${ip} "mkdir -p /etc/ssl/${service}"
    
    # Install certbot if not present
    ssh -i ~/.ssh/redteam-key -o StrictHostKeyChecking=no ubuntu@${ip} "
        command -v certbot >/dev/null 2>&1 || {
            sudo apt update
            sudo apt install -y certbot python3-certbot-nginx
            sudo apt install -y certbot python3-certbot-dns-cloudflare
        }
    "
    
    # Create certificate management script
    ssh -i ~/.ssh/redteam-key -o StrictHostKeyChecking=no ubuntu@${ip} "
        cat > /etc/ssl/${service}/cert-manager.sh << 'EOF'
#!/bin/bash
# SSL certificate management for ${service}

DOMAIN='${domain}'
SERVICE='${service}'
STEALTH_MODE='${STEALTH_MODE}'

# Function to request certificate
request_cert() {
    echo \"Requesting certificate for \$DOMAIN...\"
    
    if [[ \"\$STEALTH_MODE\" == \"high\" ]]; then
        # High stealth: Use DNS challenge only
        certbot certonly \\
            --dns-cloudflare \\
            --dns-cloudflare-credentials /etc/ssl/cloudflare.ini \\
            -d \"\$DOMAIN\" \\
            --non-interactive \\
            --agree-tos \\
            --email admin@\"\$DOMAIN\" \\
            --cert-name \"\$SERVICE\"
    else
        # Medium/Low stealth: Use HTTP challenge
        certbot certonly \\
            --nginx \\
            -d \"\$DOMAIN\" \\
            --non-interactive \\
            --agree-tos \\
            --email admin@\"\$DOMAIN\" \\
            --cert-name \"\$SERVICE\"
    fi
}

# Function to setup auto-renewal
setup_renewal() {
    echo \"Setting up auto-renewal for \$DOMAIN...\"
    
    # Create renewal script
    cat > /etc/ssl/\${SERVICE}/renew-cert.sh << 'RENEWEOF'
#!/bin/bash
# Auto-renewal script for \${SERVICE}
certbot renew --cert-name \"\${SERVICE}\" --quiet --post-hook \"systemctl reload nginx\"
RENEWEOF
    
    chmod +x /etc/ssl/\${SERVICE}/renew-cert.sh
    
    # Setup cron job for renewal
    (crontab -l 2>/dev/null; echo \"0 12 * * * /etc/ssl/\${SERVICE}/renew-cert.sh\") | crontab -
    
    echo \"Auto-renewal configured for \$DOMAIN\"
}

# Function to configure nginx SSL
configure_nginx_ssl() {
    echo \"Configuring nginx SSL for \$DOMAIN...\"
    
    cat > /etc/nginx/sites-available/\${SERVICE}-ssl.conf << 'NGINXEOF'
server {
    listen 443 ssl http2;
    server_name \$DOMAIN;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/\$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/\$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains\" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;
    
    # Service-specific configuration
    include /etc/nginx/conf.d/\${SERVICE}/*.conf;
    
    # Log configuration
    access_log /var/log/nginx/\${SERVICE}-ssl.log;
    error_log /var/log/nginx/\${SERVICE}-error.log;
    
    # Stealth configurations
    client_max_body_size 10M;
    
    location / {
        proxy_pass http://localhost;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Block common scanning paths
    location ~* \\\.(php|jsp|asp|aspx)\$ {
        deny all;
        return 404;
    }
    
    # Hide server tokens
    server_tokens off;
}
NGINXEOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/\${SERVICE}-ssl.conf /etc/nginx/sites-enabled/
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    
    echo \"Nginx SSL configuration completed for \$DOMAIN\"
}

# Main execution
echo \"Starting SSL setup for \${SERVICE} (\$DOMAIN)...\"

# Request certificate
request_cert

# Setup auto-renewal
setup_renewal

# Configure nginx
configure_nginx_ssl

echo \"SSL setup completed for \${SERVICE}\"
EOF
    "
    
    # Create CloudFlare credentials file if needed
    if [[ "$STEALTH_MODE" == "high" ]]; then
        echo "Creating CloudFlare DNS credentials..."
        ssh -i ~/.ssh/redteam-key -o StrictHostKeyChecking=no ubuntu@${ip} "
            cat > /etc/ssl/cloudflare.ini << 'CLOUDFLAREEOF'
dns_cloudflare_api_token = YOUR_CLOUDFLARE_API_TOKEN
dns_cloudzone_api_token = YOUR_CLOUDFLARE_ZONE_TOKEN
CLOUDFLAREEOF
            
            chmod 600 /etc/ssl/cloudflare.ini
        "
    fi
    
    # Make certificate manager executable
    ssh -i ~/.ssh/redteam-key -o StrictHostKeyChecking=no ubuntu@${ip} "chmod +x /etc/ssl/${service}/cert-manager.sh"
    
    # Run certificate setup
    ssh -i ~/.ssh/redteam-key -o StrictHostKeyChecking=no ubuntu@${ip} "/etc/ssl/${service}/cert-manager.sh"
    
    log "SSL setup completed for ${service}"
}

# Setup certificates for all services
setup_all_ssl() {
    local output_file="$1"
    
    if [[ ! -f "$output_file" ]]; then
        error "Output file not found: $output_file"
    fi
    
    # Load service IPs
    if command -v jq >/dev/null 2>&1; then
        mythic_ip=$(jq -r '.mythic_instance_ip.value // empty' "$output_file")
        gophish_ip=$(jq -r '.gophish_instance_ip.value // empty' "$output_file")
        evilginx_ip=$(jq -r '.evilginx_instance_ip.value // empty' "$output_file")
        pwndrop_ip=$(jq -r '.pwndrop_instance_ip.value // empty' "$output_file")
    else
        error "jq is required to parse output file"
    fi
    
    header "SSL CERTIFICATE SETUP"
    
    # Get base domain
    read -p "Enter base domain (e.g., example.com): " base_domain
    
    # Generate obfuscated domains for each service
    log "Generating obfuscated domains for stealth..."
    
    mythic_domains=$(generate_obfuscated_domains "$base_domain" "mythic")
    gophish_domains=$(generate_obfuscated_domains "$base_domain" "gophish")
    evilginx_domains=$(generate_obfuscated_domains "$base_domain" "evilginx")
    pwndrop_domains=$(generate_obfuscated_domains "$base_domain" "pwndrop")
    
    echo ""
    info "Generated Domains:"
    echo "Mythic: $mythic_domains"
    echo "GoPhish: $gophish_domains"
    echo "Evilginx: $evilginx_domains"
    echo "Pwndrop: $pwndrop_domains"
    echo ""
    
    # Setup SSL for each service
    if [[ -n "$mythic_ip" && "$mythic_ip" != "empty" ]]; then
        read -p "Enter Mythic domain from above list: " mythic_domain
        setup_service_ssl "$mythic_ip" "mythic" "$mythic_domain"
    fi
    
    if [[ -n "$gophish_ip" && "$gophish_ip" != "empty" ]]; then
        read -p "Enter GoPhish domain from above list: " gophish_domain
        setup_service_ssl "$gophish_ip" "gophish" "$gophish_domain"
    fi
    
    if [[ -n "$evilginx_ip" && "$evilginx_ip" != "empty" ]]; then
        read -p "Enter Evilginx domain from above list: " evilginx_domain
        setup_service_ssl "$evilginx_ip" "evilginx" "$evilginx_domain"
    fi
    
    if [[ -n "$pwndrop_ip" && "$pwndrop_ip" != "empty" ]]; then
        read -p "Enter Pwndrop domain from above list: " pwndrop_domain
        setup_service_ssl "$pwndrop_ip" "pwndrop" "$pwndrop_domain"
    fi
}

# Create DNS configuration file
create_dns_config() {
    local output_file="$1"
    
    header "DNS CONFIGURATION"
    
    # Load service IPs
    if command -v jq >/dev/null 2>&1; then
        mythic_ip=$(jq -r '.mythic_instance_ip.value // empty' "$output_file")
        gophish_ip=$(jq -r '.gophish_instance_ip.value // empty' "$output_file")
        evilginx_ip=$(jq -r '.evilginx_instance_ip.value // empty' "$output_file")
        pwndrop_ip=$(jq -r '.pwndrop_instance_ip.value // empty' "$output_file")
    fi
    
    # Get base domain
    read -p "Enter base domain for DNS config: " base_domain
    
    # Create DNS configuration
    cat > dns-config-ssl.json << EOF
{
  "dns_provider": "cloudflare",
  "base_domain": "$base_domain",
  "services": {
    "mythic": {
      "domains": ["c2-${base_domain}", "control-${base_domain}"],
      "ip": "$mythic_ip",
      "ports": [443, 7443]
    },
    "gophish": {
      "domains": ["phish-${base_domain}", "login-${base_domain}"],
      "ip": "$gophish_ip",
      "ports": [443, 3333]
    },
    "evilginx": {
      "domains": ["proxy-${base_domain}", "tunnel-${base_domain}"],
      "ip": "$evilginx_ip",
      "ports": [443, 8080]
    },
    "pwndrop": {
      "domains": ["files-${base_domain}", "download-${base_domain}"],
      "ip": "$pwndrop_ip",
      "ports": [443, 8080]
    }
  },
  "cloudflare": {
    "api_token": "YOUR_CLOUDFLARE_API_TOKEN",
    "zone_id": "YOUR_CLOUDFLARE_ZONE_ID"
  },
  "ssl_config": {
    "auto_renewal": true,
    "renewal_time": "12:00",
    "stealth_mode": "$STEALTH_MODE",
    "challenge_type": "$([ "$STEALTH_MODE" = "high" ] && echo "dns" || echo "http")"
  }
}
EOF
    
    log "DNS configuration created: dns-config-ssl.json"
    
    echo ""
    info "Next steps:"
    echo "1. Update CloudFlare API tokens in dns-config-ssl.json"
    echo "2. Update DNS records: python3 update-dns.py --config dns-config-ssl.json --all"
    echo "3. Verify SSL certificates: python3 verify-ssl.py --config dns-config-ssl.json"
}

# Main function
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <outputs_file> [stealth_mode]"
        echo "Example: $0 outputs/aws_primary.json high"
        echo ""
        echo "Options:"
        echo "  outputs_file  - Terraform outputs JSON file"
        echo "  stealth_mode - Stealth level (high, medium, low)"
        exit 1
    fi
    
    local output_file="$1"
    local stealth_mode="${2:-high}"
    
    header "STEALTH-ENHANCED SSL CERTIFICATE SETUP"
    
    if [[ ! -f "$output_file" ]]; then
        error "Output file not found: $output_file"
    fi
    
    echo "SSL Setup Options:"
    echo "1) Setup SSL certificates for all services"
    echo "2) Create DNS configuration only"
    echo ""
    
    read -p "Enter your choice [1-2]: " choice
    
    case $choice in
        1)
            setup_all_ssl "$output_file"
            ;;
        2)
            create_dns_config "$output_file"
            ;;
        *)
            error "Invalid choice: $choice"
            ;;
    esac
    
    log "SSL setup process completed"
}

# Run main function
main "$@"
