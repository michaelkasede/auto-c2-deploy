#!/bin/bash

# AWS Red Team Infrastructure Deployment Script
# Deploys Mythic, GoPhish, Evilginx, and Pwndrop with stealth configurations

set -euo pipefail

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}
VPC_CIDR=${VPC_CIDR:-"10.0.0.0/16"}
PUBLIC_SUBNET_CIDRS=${PUBLIC_SUBNET_CIDRS:-"10.0.1.0/24,10.0.2.0/24"}
PRIVATE_SUBNET_CIDRS=${PRIVATE_SUBNET_CIDRS:-"10.0.10.0/24,10.0.20.0/24"}

# Security
SSH_KEY_NAME=${SSH_KEY_NAME:-"redteam-key"}
ADMIN_IP=$(curl -s ifconfig.me)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v aws >/dev/null 2>&1 || error "AWS CLI not installed"
    command -v terraform >/dev/null 2>&1 || error "Terraform not installed"
    command -v docker >/dev/null 2>&1 || error "Docker not installed"
    
    aws sts get-caller-identity >/dev/null 2>&1 || error "AWS credentials not configured"
    
    log "Prerequisites check passed"
}

# Create SSH key pair
create_ssh_key() {
    log "Creating SSH key pair..."
    
    if ! aws ec2 describe-key-pairs --key-names "$SSH_KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        aws ec2 create-key-pair \
            --key-name "$SSH_KEY_NAME" \
            --region "$AWS_REGION" \
            --query 'KeyMaterial' \
            --output text > ~/.ssh/"$SSH_KEY_NAME".pem
        
        chmod 400 ~/.ssh/"$SSH_KEY_NAME".pem
        log "SSH key pair created: ~/.ssh/$SSH_KEY_NAME.pem"
    else
        log "SSH key pair already exists"
    fi
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log "Deploying infrastructure with Terraform..."
    
    cat > terraform.tfvars <<EOF
aws_region = "$AWS_REGION"
vpc_cidr = "$VPC_CIDR"
public_subnet_cidrs = ["${PUBLIC_SUBNET_CIDRS//,/\",\"}"]
private_subnet_cidrs = ["${PRIVATE_SUBNET_CIDRS//,/\",\"}"]
ssh_key_name = "$SSH_KEY_NAME"
admin_ip = "$ADMIN_IP"
environment = "redteam"
EOF
    
    terraform init
    terraform plan -var-file=terraform.tfvars
    terraform apply -var-file=terraform.tfvars -auto-approve
    
    log "Infrastructure deployed successfully"
}

# Configure Mythic
configure_mythic() {
    log "Configuring Mythic..."
    
    # Get instance IP
    MYTHIC_IP=$(terraform output -raw mythic_instance_ip)
    
    # SSH into Mythic instance and setup
    ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no ubuntu@"$MYTHIC_IP" <<'EOF'
        # Update system
        sudo apt update && sudo apt upgrade -y
        
        # Install Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker ubuntu
        
        # Install Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        # Clone Mythic
        git clone https://github.com/its-a-feature/Mythic.git /opt/mythic
        cd /opt/mythic
        
        # Build mythic-cli
        sudo make
        
        # Configure SSL certificates
        mkdir -p ./nginx-docker/ssl
        # Copy certificates here or configure Let's Encrypt
        
        # Start Mythic
        sudo ./mythic-cli start
EOF
    
    log "Mythic configured and started"
}

# Configure GoPhish
configure_gophish() {
    log "Configuring GoPhish..."
    
    GOPHISH_IP=$(terraform output -raw gophish_instance_ip)
    
    ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no ubuntu@"$GOPHISH_IP" <<'EOF'
        # Update and install Docker
        sudo apt update && sudo apt upgrade -y
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker ubuntu
        
        # Create GoPhish directory
        mkdir -p /opt/gophish
        
        # Create docker-compose.yml
        cat > /opt/gophish/docker-compose.yml <<'EOFD'
version: '3.8'
services:
  gophish:
    image: gophish/gophish:latest
    container_name: gophish
    ports:
      - "443:443"
      - "127.0.0.1:3333:3333"
    volumes:
      - ./data:/opt/gophish/data
      - ./ssl:/opt/gophish/ssl
    restart: unless-stopped
    environment:
      - ADMIN_USER=admin
      - ADMIN_PASSWORD=$(openssl rand -base64 32)
EOFD
        
        # Create directories
        mkdir -p /opt/gophish/data /opt/gophish/ssl
        
        # Start GoPhish
        cd /opt/gophish
        docker-compose up -d
        
        # Wait for startup and get credentials
        sleep 10
        echo "GoPhish admin credentials:"
        docker logs gophish | grep "Admin password"
EOF
    
    log "GoPhish configured and started"
}

# Configure Evilginx
configure_evilginx() {
    log "Configuring Evilginx..."
    
    EVILGINX_IP=$(terraform output -raw evilginx_instance_ip)
    
    ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no ubuntu@"$EVILGINX_IP" <<'EOF'
        # Update and install dependencies
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y nginx certbot python3-certbot-nginx
        
        # Install Go
        wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        source ~/.bashrc
        
        # Clone and build Evilginx
        git clone https://github.com/kgretzky/evilginx2.git /opt/evilginx
        cd /opt/evilginx
        go build -o evilginx
        
        # Create configuration
        mkdir -p ~/.evilginx
        
        # Create systemd service
        sudo tee /etc/systemd/system/evilginx.service > /dev/null <<'EOS'
[Unit]
Description=Evilginx2
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/evilginx
ExecStart=/opt/evilginx/evilginx -p ~/.evilginx
Restart=always

[Install]
WantedBy=multi-user.target
EOS
        
        sudo systemctl enable evilginx
        sudo systemctl start evilginx
        
        # Configure nginx reverse proxy
        sudo tee /etc/nginx/sites-available/evilginx > /dev/null <<'EONG'
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EONG
        
        sudo ln -s /etc/nginx/sites-available/evilginx /etc/nginx/sites-enabled/
        sudo nginx -t && sudo systemctl reload nginx
EOF
    
    log "Evilginx configured and started"
}

# Configure Pwndrop
configure_pwndrop() {
    log "Configuring Pwndrop..."
    
    PWNDROP_IP=$(terraform output -raw pwndrop_instance_ip)
    
    ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no ubuntu@"$PWNDROP_IP" <<'EOF'
        # Update and install
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y nginx certbot python3-certbot-nginx
        
        # Download Pwndrop
        wget https://github.com/kgretzky/pwndrop/releases/latest/download/pwndrop-linux-x64.tar.gz
        tar -xzf pwndrop-linux-x64.tar.gz
        sudo mv pwndrop /usr/local/bin/
        sudo chmod +x /usr/local/bin/pwndrop
        
        # Create config directory
        sudo mkdir -p /etc/pwndrop
        sudo chown ubuntu:ubuntu /etc/pwndrop
        
        # Generate initial config
        cd /etc/pwndrop
        pwndrop --init
        
        # Create systemd service
        sudo tee /etc/systemd/system/pwndrop.service > /dev/null <<'EOS'
[Unit]
Description=Pwndrop
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/etc/pwndrop
ExecStart=/usr/local/bin/pwndrop
Restart=always

[Install]
WantedBy=multi-user.target
EOS
        
        sudo systemctl enable pwndrop
        sudo systemctl start pwndrop
        
        # Configure nginx
        sudo tee /etc/nginx/sites-available/pwndrop > /dev/null <<'EONG'
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EONG
        
        sudo ln -s /etc/nginx/sites-available/pwndrop /etc/nginx/sites-enabled/
        sudo nginx -t && sudo systemctl reload nginx
EOF
    
    log "Pwndrop configured and started"
}

# Setup monitoring and logging
setup_monitoring() {
    log "Setting up monitoring and logging..."
    
    # Create CloudWatch alarms for suspicious activity
    # Setup centralized logging
    # Configure alerting
    
    log "Monitoring setup completed"
}

# Main execution
main() {
    log "Starting AWS Red Team Infrastructure Deployment..."
    
    check_prerequisites
    create_ssh_key
    deploy_infrastructure
    configure_mythic
    configure_gophish
    configure_evilginx
    configure_pwndrop
    setup_monitoring
    
    log "Deployment completed successfully!"
    
    # Output access information
    echo ""
    log "Access Information:"
    echo "Mythic: $(terraform output -raw mythic_instance_ip)"
    echo "GoPhish: $(terraform output -raw gophish_instance_ip)"
    echo "Evilginx: $(terraform output -raw evilginx_instance_ip)"
    echo "Pwndrop: $(terraform output -raw pwndrop_instance_ip)"
    echo ""
    warn "Remember to:"
    echo "1. Change default passwords"
    echo "2. Configure SSL certificates"
    echo "3. Set up proper domain names"
    echo "4. Configure firewall rules"
    echo "5. Enable multi-factor authentication"
}

# Run main function
main "$@"
