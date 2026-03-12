#!/bin/bash
# Cloud-init script for Evilginx instance

# Set hostname
hostnamectl set-hostname ${hostname}

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y nginx certbot python3-certbot-nginx wget unzip htop

# Install Go
cd /tmp
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

# Clone and build Evilginx
cd /opt
git clone https://github.com/kgretzky/evilginx2.git evilginx
cd evilginx
/usr/local/go/bin/go build -o evilginx

# Create evilginx user
useradd -r -s /bin/false evilginx
mkdir -p /home/evilginx/.evilginx
chown -R evilginx:evilginx /home/evilginx

# Create systemd service
cat > /etc/systemd/system/evilginx.service << 'EOF'
[Unit]
Description=Evilginx2 Phishing Framework
After=network.target

[Service]
Type=simple
User=evilginx
Group=evilginx
WorkingDirectory=/opt/evilginx
ExecStart=/opt/evilginx/evilginx -p /home/evilginx/.evilginx
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create configuration
mkdir -p /home/evilginx/.evilginx/sessions
chown -R evilginx:evilginx /home/evilginx/.evilginx

# Generate initial config
cat > /home/evilginx/.evilginx/config.json << 'EOF'
{
    "debug": false,
    "proxy_addr": "127.0.0.1:8080",
    "proxy_domain": "localhost",
    "tls_cert_path": "",
    "tls_key_path": "",
    "phishlets_dir": "/opt/evilginx/phishlets",
    "redirectors_dir": "/home/evilginx/.evilginx/redirectors",
    "sessions_dir": "/home/evilginx/.evilginx/sessions",
    "log_dir": "/home/evilginx/.evilginx/logs"
}
EOF

chown evilginx:evilginx /home/evilginx/.evilginx/config.json

# Create log directory
mkdir -p /home/evilginx/.evilginx/logs
chown evilginx:evilginx /home/evilginx/.evilginx/logs

# Configure nginx reverse proxy
cat > /etc/nginx/sites-available/evilginx << 'EOF'
server {
    listen 80;
    server_name your-evilginx-domain.com;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-evilginx-domain.com;
    
    # SSL configuration (will be configured by certbot)
    ssl_certificate /etc/letsencrypt/live/your-evilginx-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-evilginx-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Block access to admin interface from external
    location /admin {
        deny all;
        return 404;
    }
}
EOF

# Enable site (will need domain configuration)
# ln -s /etc/nginx/sites-available/evilginx /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Create admin script for managing evilginx
cat > /usr/local/bin/evilginx-admin << 'EOF'
#!/bin/bash
# Evilginx administration script

case "$1" in
    start)
        systemctl start evilginx
        echo "Evilginx started"
        ;;
    stop)
        systemctl stop evilginx
        echo "Evilginx stopped"
        ;;
    restart)
        systemctl restart evilginx
        echo "Evilginx restarted"
        ;;
    status)
        systemctl status evilginx
        ;;
    logs)
        tail -f /home/evilginx/.evilginx/logs/evilginx.log
        ;;
    *)
        echo "Usage: evilginx-admin {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/evilginx-admin

# Create backup script
cat > /opt/evilginx/backup.sh << 'EOF'
#!/bin/bash
# Backup Evilginx data

BACKUP_DIR="/opt/evilginx/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configuration and sessions
tar -czf $BACKUP_DIR/evilginx_$DATE.tar.gz /home/evilginx/.evilginx/

# Clean old backups (keep last 7 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /opt/evilginx/backup.sh

# Add cron job for daily backup
echo "0 3 * * * /opt/evilginx/backup.sh" | crontab -

# Configure firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Enable and start evilginx
systemctl enable evilginx
systemctl start evilginx

echo "Evilginx setup completed"
echo "Management: evilginx-admin {start|stop|restart|status|logs}"
echo "Default admin credentials will be created on first run"
