#!/bin/bash
# Cloud-init script for GoPhish instance

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
apt-get install -y nginx certbot python3-certbot-nginx htop

# Create GoPhish directory
mkdir -p /opt/gophish
cd /opt/gophish

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
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
      - ./config:/opt/gophish/config
    restart: unless-stopped
    environment:
      - ADMIN_USER=admin
      - TZ=UTC
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3333"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# Create directories
mkdir -p data ssl config

# Generate random admin password
ADMIN_PASSWORD=$(openssl rand -base64 32)
echo "Admin Password: $ADMIN_PASSWORD" > /opt/gophish/admin_password.txt
chmod 600 /opt/gophish/admin_password.txt

# Create initial config
cat > config/config.json << 'EOF'
{
    "admin_server": {
        "listen_url": "0.0.0.0:3333",
        "use_tls": false,
        "cert_path": "",
        "key_path": ""
    },
    "phish_server": {
        "listen_url": "0.0.0.0:443",
        "use_tls": true,
        "cert_path": "/opt/gophish/ssl/fullchain.pem",
        "key_path": "/opt/gophish/ssl/privkey.pem"
    },
    "db_name": "sqlite3",
    "db_path": "/opt/gophish/data/gophish.db",
    "migrations_prefix": "db/db_",
    "contact_address": "",
    "logging": {
        "filename": "/opt/gophish/data/gophish.log",
        "level": "info"
    }
}
EOF

# Start GoPhish
docker-compose up -d

# Wait for startup
sleep 10

# Configure nginx reverse proxy (optional)
cat > /etc/nginx/sites-available/gophish << 'EOF'
server {
    listen 80;
    server_name your-phishing-domain.com;
    
    location / {
        proxy_pass https://localhost:443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site if domain is configured
# ln -s /etc/nginx/sites-available/gophish /etc/nginx/sites-enabled/

# Configure log rotation
cat > /etc/logrotate.d/gophish << 'EOF'
/opt/gophish/data/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
}
EOF

# Create backup script
cat > /opt/gophish/backup.sh << 'EOF'
#!/bin/bash
# Backup GoPhish data

BACKUP_DIR="/opt/gophish/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
cp /opt/gophish/data/gophish.db $BACKUP_DIR/gophish_$DATE.db

# Backup config
tar -czf $BACKUP_DIR/config_$DATE.tar.gz /opt/gophish/config/

# Clean old backups (keep last 7 days)
find $BACKUP_DIR -name "*.db" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /opt/gophish/backup.sh

# Add cron job for daily backup
echo "0 2 * * * /opt/gophish/backup.sh" | crontab -

# Configure firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 443/tcp
ufw allow from 127.0.0.1 to any port 3333 proto tcp

# Create monitoring script
cat > /opt/gophish/monitor.sh << 'EOF'
#!/bin/bash
# Monitor GoPhish container

if ! docker ps | grep -q "gophish"; then
    echo "WARNING: GoPhish container is not running"
    cd /opt/gophish
    docker-compose up -d
fi
EOF

chmod +x /opt/gophish/monitor.sh

# Add cron job for monitoring
echo "*/5 * * * * /opt/gophish/monitor.sh >> /var/log/gophish-monitor.log 2>&1" | crontab -

echo "GoPhish setup completed"
echo "Admin interface: http://localhost:3333"
echo "Admin password saved in /opt/gophish/admin_password.txt"
