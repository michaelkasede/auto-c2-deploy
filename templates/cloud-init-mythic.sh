#!/bin/bash
# Cloud-init script for Mythic instance

# Set hostname
hostnamectl set-hostname ${hostname}

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install additional tools
apt-get install -y git htop nginx certbot python3-certbot-nginx

# Create Mythic directory
mkdir -p /opt/mythic
cd /opt/mythic

# Clone Mythic
git clone https://github.com/its-a-feature/Mythic.git .

# Build mythic-cli
make

# Configure SSL directory
mkdir -p ./nginx-docker/ssl

# Create systemd service for mythic
cat > /etc/systemd/system/mythic.service << 'EOF'
[Unit]
Description=Mythic C2 Framework
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/mythic
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start mythic service
systemctl enable mythic

# Configure log rotation
cat > /etc/logrotate.d/mythic << 'EOF'
/opt/mythic/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
}
EOF

# Add user to docker group
usermod -aG docker ubuntu

# Create monitoring script
cat > /opt/mythic/monitor.sh << 'EOF'
#!/bin/bash
# Basic health check for Mythic containers

containers=("mythic_nginx_1" "mythic_react_1" "mythic_server_1" "mythic_hasura_1" "mythic_postgres_1" "mythic_rabbitmq_1")

for container in "${containers[@]}"; do
    if ! docker ps | grep -q "$container"; then
        echo "WARNING: Container $container is not running"
        # Send alert or restart logic here
    fi
done
EOF

chmod +x /opt/mythic/monitor.sh

# Add cron job for monitoring
echo "*/5 * * * * /opt/mythic/monitor.sh >> /var/log/mythic-monitor.log 2>&1" | crontab -

# Configure firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 7443/tcp

# Reboot to apply all changes
reboot
