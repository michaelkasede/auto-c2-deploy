#!/bin/bash
# Cloud-init script for Pwndrop instance

# Set hostname
hostnamectl set-hostname ${hostname}

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y nginx certbot python3-certbot-nginx wget htop

# Download and install Pwndrop
cd /tmp
wget https://github.com/kgretzky/pwndrop/releases/latest/download/pwndrop-linux-x64.tar.gz
tar -xzf pwndrop-linux-x64.tar.gz
mv pwndrop /usr/local/bin/
chmod +x /usr/local/bin/pwndrop

# Create pwndrop user
useradd -r -s /bin/false pwndrop
mkdir -p /etc/pwndrop
chown -R pwndrop:pwndrop /etc/pwndrop

# Create systemd service
cat > /etc/systemd/system/pwndrop.service << 'EOF'
[Unit]
Description=Pwndrop File Server
After=network.target

[Service]
Type=simple
User=pwndrop
Group=pwndrop
WorkingDirectory=/etc/pwndrop
ExecStart=/usr/local/bin/pwndrop
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Initialize pwndrop configuration
cd /etc/pwndrop
sudo -u pwndrop /usr/local/bin/pwndrop --init

# Create custom configuration
cat > /etc/pwndrop/pwndrop.toml << 'EOF'
[server]
host = "0.0.0.0"
port = 8080
secret = "your-secret-key-here"

[admin]
username = "admin"
password = "change-this-password"

[upload]
max_size = 104857600  # 100MB
allowed_exts = [".exe", ".dll", ".ps1", ".bat", ".sh", ".py", ".zip", ".rar"]

[security]
hide_files = true
random_paths = true
rate_limit = 10
EOF

# Generate random secret
SECRET=$(openssl rand -hex 32)
sed -i "s/your-secret-key-here/$SECRET/" /etc/pwndrop/pwndrop.toml

# Generate random admin password
ADMIN_PASSWORD=$(openssl rand -base64 32)
sed -i "s/change-this-password/$ADMIN_PASSWORD/" /etc/pwndrop/pwndrop.toml

echo "Admin Password: $ADMIN_PASSWORD" > /etc/pwndrop/admin_password.txt
chmod 600 /etc/pwndrop/admin_password.txt

# Configure nginx reverse proxy
cat > /etc/nginx/sites-available/pwndrop << 'EOF'
server {
    listen 80;
    server_name your-pwndrop-domain.com;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-pwndrop-domain.com;
    
    # SSL configuration (will be configured by certbot)
    ssl_certificate /etc/letsencrypt/live/your-pwndrop-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-pwndrop-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    # Hide server identity
    server_tokens off;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Increase timeout for large file uploads
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
    
    # Block access to admin interface from external
    location /admin {
        deny all;
        return 404;
    }
    
    # Add custom headers for stealth
    add_header Server "Apache/2.4.41 (Ubuntu)";
    add_header X-Powered-By "PHP/7.4.3";
}
EOF

# Enable site (will need domain configuration)
# ln -s /etc/nginx/sites-available/pwndrop /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Create admin script for managing pwndrop
cat > /usr/local/bin/pwndrop-admin << 'EOF'
#!/bin/bash
# Pwndrop administration script

case "$1" in
    start)
        systemctl start pwndrop
        echo "Pwndrop started"
        ;;
    stop)
        systemctl stop pwndrop
        echo "Pwndrop stopped"
        ;;
    restart)
        systemctl restart pwndrop
        echo "Pwndrop restarted"
        ;;
    status)
        systemctl status pwndrop
        ;;
    logs)
        journalctl -u pwndrop -f
        ;;
    config)
        echo "Admin password: $(cat /etc/pwndrop/admin_password.txt)"
        ;;
    *)
        echo "Usage: pwndrop-admin {start|stop|restart|status|logs|config}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/pwndrop-admin

# Create backup script
cat > /opt/pwndrop/backup.sh << 'EOF'
#!/bin/bash
# Backup Pwndrop data

BACKUP_DIR="/opt/pwndrop/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configuration and data
tar -czf $BACKUP_DIR/pwndrop_$DATE.tar.gz /etc/pwndrop/

# Clean old backups (keep last 7 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /opt/pwndrop/backup.sh

# Add cron job for daily backup
echo "0 4 * * * /opt/pwndrop/backup.sh" | crontab -

# Create file cleanup script
cat > /opt/pwndrop/cleanup.sh << 'EOF'
#!/bin/bash
# Clean up old files in pwndrop

# Remove files older than 30 days
find /etc/pwndrop/data -type f -mtime +30 -delete

# Remove empty directories
find /etc/pwndrop/data -type d -empty -delete
EOF

chmod +x /opt/pwndrop/cleanup.sh

# Add cron job for weekly cleanup
echo "0 5 * * 0 /opt/pwndrop/cleanup.sh" | crontab -

# Configure firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Enable and start pwndrop
systemctl enable pwndrop
systemctl start pwndrop

echo "Pwndrop setup completed"
echo "Management: pwndrop-admin {start|stop|restart|status|logs|config}"
echo "Admin password saved in /etc/pwndrop/admin_password.txt"
