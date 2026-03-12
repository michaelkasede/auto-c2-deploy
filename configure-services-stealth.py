#!/usr/bin/env python3

# Stealth-Enhanced Service Configuration
# Configures services with stealth considerations

import json
import sys
import os
import subprocess
import logging
import argparse
from typing import Dict, Any, List, Optional

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class StealthServiceConfigurator:
    def __init__(self, provider: str, mode: str, outputs_file: str, stealth_mode: str = "high"):
        self.provider = provider.lower()
        self.mode = mode.lower()
        self.stealth_mode = stealth_mode.lower()
        self.outputs_file = outputs_file
        self.outputs = self._load_outputs()
        
    def _load_outputs(self) -> Dict[str, Any]:
        """Load Terraform outputs from JSON file"""
        try:
            with open(self.outputs_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.error(f"Outputs file not found: {self.outputs_file}")
            return {}
        except json.JSONDecodeError:
            logger.error(f"Invalid JSON in outputs file: {self.outputs_file}")
            return {}
    
    def get_instance_ips(self) -> Dict[str, str]:
        """Extract instance IPs based on cloud provider"""
        ips = {}
        
        if self.provider == "aws":
            ips = {
                "mythic": self.outputs.get("mythic_instance_ip", {}).get("value", ""),
                "gophish": self.outputs.get("gophish_instance_ip", {}).get("value", ""),
                "evilginx": self.outputs.get("evilginx_instance_ip", {}).get("value", ""),
                "pwndrop": self.outputs.get("pwndrop_instance_ip", {}).get("value", "")
            }
        elif self.provider == "azure":
            ips = {
                "mythic": self.outputs.get("mythic_public_ip", {}).get("value", ""),
                "gophish": self.outputs.get("gophish_public_ip", {}).get("value", ""),
                "evilginx": self.outputs.get("evilginx_public_ip", {}).get("value", ""),
                "pwndrop": self.outputs.get("pwndrop_public_ip", {}).get("value", "")
            }
        elif self.provider == "gcp":
            ips = {
                "mythic": self.outputs.get("mythic_instance_ip", {}).get("value", ""),
                "gophish": self.outputs.get("gophish_instance_ip", {}).get("value", ""),
                "evilginx": self.outputs.get("evilginx_instance_ip", {}).get("value", ""),
                "pwndrop": self.outputs.get("pwndrop_instance_ip", {}).get("value", "")
            }
        
        return {k: v for k, v in ips.items() if v}
    
    def ssh_command(self, ip: str, command: str, timeout: int = 300) -> bool:
        """Execute SSH command on remote instance"""
        ssh_key = "~/.ssh/redteam-key"
        ssh_cmd = f"ssh -i {ssh_key} -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes ubuntu@{ip} '{command}'"
        
        try:
            result = subprocess.run(ssh_cmd, shell=True, capture_output=True, text=True, timeout=timeout)
            if result.returncode == 0:
                logger.info(f"Command executed successfully on {ip}")
                return True
            else:
                logger.error(f"Command failed on {ip}: {result.stderr}")
                return False
        except subprocess.TimeoutExpired:
            logger.error(f"SSH command timed out on {ip}")
            return False
        except Exception as e:
            logger.error(f"SSH error on {ip}: {str(e)}")
            return False
    
    def configure_mythic_stealth(self, ip: str) -> bool:
        """Configure Mythic with stealth settings"""
        logger.info(f"Configuring stealth-enhanced Mythic on {ip}")
        
        commands = [
            # Wait for system to be ready
            "sleep 30",
            
            # Install Docker if not present
            "command -v docker >/dev/null 2>&1 || {",
            "  curl -fsSL https://get.docker.com -o get-docker.sh",
            "  sudo sh get-docker.sh",
            "  sudo usermod -aG docker ubuntu",
            "}",
            
            # Create stealth monitoring configuration
            "mkdir -p /opt/mythic/monitoring",
            
            # Create stealth docker-compose for Mythic
            "cat > /opt/mythic/docker-compose.stealth.yml << 'EOF'",
            "version: '3.8'",
            "services:",
            "  mythic:",
            "    image: its-a-feature/mythic:latest",
            "    container_name: mythic",
            "    ports:",
            "      - '7443:7443'",
            "      - '80:80'",
            "      - '443:443'",
            "    volumes:",
            "      - ./ssl:/etc/ssl/mythic",
            "      - ./data:/opt/mythic/data",
            "    environment:",
            "      - MYTHIC_ENV=production",
            "      - STEALTH_MODE=" + self.stealth_mode,
            "    restart: unless-stopped",
            "    logging:",
            "      driver: 'json-file'",
            "      options:",
            "        max-size: '10m'",
            "        max-file: '3'",
            "",
            ]
            
            # Configure based on stealth level
            self._configure_mythic_monitoring(ip),
            
            # Start Mythic
            "cd /opt/mythic && sudo docker-compose -f docker-compose.stealth.yml up -d",
            
            # Wait for startup
            "sleep 60",
            
            # Verify services
            "docker ps | grep mythic"
        ]
        
        for cmd in commands:
            if not self.ssh_command(ip, cmd):
                logger.error(f"Failed to execute command on Mythic instance: {cmd}")
                return False
        
        return True
    
    def _configure_mythic_monitoring(self, ip: str):
        """Configure Mythic monitoring based on stealth level"""
        if self.stealth_mode == "high":
            # High stealth: minimal monitoring only
            commands = [
                # Create basic health check script
                "cat > /opt/mythic/health-check.sh << 'EOF'",
                "#!/bin/bash",
                "# Basic health check for Mythic",
                "CONTAINER_STATUS=$(docker ps --format 'table {{.Names}}\\t{{.Status}}' | grep mythic | awk '{print $2}')",
                "if [[ \"$CONTAINER_STATUS\" == \"Up\" ]]; then",
                "  echo \"Mythic container is running\"",
                "else",
                "  echo \"Mythic container is down\"",
                "  exit 1",
                "fi",
                "EOF",
                
                # Make executable
                "chmod +x /opt/mythic/health-check.sh",
                
                # Create log rotation script
                "cat > /opt/mythic/rotate-logs.sh << 'EOF'",
                "#!/bin/bash",
                "# Rotate Mythic logs for stealth",
                "find /var/lib/docker/containers/ -name \"*.log\" -mtime +7 -delete",
                "docker system prune -f",
                "EOF",
                
                "chmod +x /opt/mythic/rotate-logs.sh",
                
                # Set up cron jobs for log rotation
                "echo '0 2 * * * /opt/mythic/rotate-logs.sh' | crontab -"
            ]
            
        elif self.stealth_mode == "medium":
            # Medium stealth: basic health checks
            commands = [
                # Create health monitoring script
                "cat > /opt/mythic/health-monitor.sh << 'EOF'",
                "#!/bin/bash",
                "# Health monitoring with basic metrics",
                "CONTAINER_STATUS=$(docker ps --format 'table {{.Names}}\\t{{.Status}}' | grep mythic)",
                "MEMORY_USAGE=$(docker stats --no-stream --format 'table {{.MemPerc}}' mythic | tail -n +2)",
                "echo \"$(date): Mythic Status: $CONTAINER_STATUS\"",
                "echo \"$(date): Memory Usage: $MEMORY_USAGE\"",
                "EOF",
                
                "chmod +x /opt/mythic/health-monitor.sh",
                
                # Set up periodic health checks
                "echo '*/30 * * * * /opt/mythic/health-monitor.sh >> /opt/mythic/health.log' | crontab -"
            ]
            
        elif self.stealth_mode == "low":
            # Low stealth: full monitoring (not recommended for red team)
            commands = [
                # Install node exporter for full monitoring
                "docker run -d --name node-exporter \\",
                "  -p 9100:9100 \\",
                "  --restart unless-stopped \\",
                "  prom/node-exporter",
                
                # Create full monitoring script
                "cat > /opt/mythic/full-monitor.sh << 'EOF'",
                "#!/bin/bash",
                "# Full monitoring setup",
                "# Prometheus metrics endpoint enabled",
                "# Grafana dashboard accessible",
                "EOF",
                
                "chmod +x /opt/mythic/full-monitor.sh"
            ]
        
        for cmd in commands:
            self.ssh_command(ip, cmd)
    
    def configure_other_service_stealth(self, ip: str, service: str) -> bool:
        """Configure GoPhish, Evilginx, or Pwndrop with stealth"""
        logger.info(f"Configuring stealth-enhanced {service} on {ip}")
        
        if self.stealth_mode == "high":
            # High stealth: manual checks only
            commands = [
                # Install service without monitoring
                f"mkdir -p /opt/{service}",
                
                # Create stealth service configuration
                f"cat > /opt/{service}/stealth-config.yml << 'EOF'",
                "stealth:",
                "  level: 'high'",
                "  monitoring: 'manual'",
                "  log_rotation: true",
                "  auto_cleanup: true",
                "  evidence_distribution: 'distributed'",
                "EOF",
                
                # Disable metrics endpoints
                "mkdir -p /etc/nginx/conf.d",
                "cat > /etc/nginx/conf.d/disable-metrics.conf << 'EOF'",
                "location /metrics {",
                "    deny all;",
                "    return 404;",
                "}",
                "location /status {",
                "    deny all;",
                "    return 404;",
                "}",
                "EOF"
            ]
            
        elif self.stealth_mode == "medium":
            # Medium stealth: basic health checks
            commands = [
                f"mkdir -p /opt/{service}",
                
                # Create medium stealth configuration
                f"cat > /opt/{service}/medium-config.yml << 'EOF'",
                "stealth:",
                "  level: 'medium'",
                "  monitoring: 'basic_health'",
                "  log_rotation: true",
                "  auto_cleanup: true",
                "  evidence_distribution: 'partial'",
                "EOF",
                
                # Create basic health check script
                f"cat > /opt/{service}/health-check.sh << 'EOF'",
                "#!/bin/bash",
                "# Basic health check",
                "SERVICE_STATUS=$(systemctl is-active {service})",
                "echo \"$(date): {service} Status: $SERVICE_STATUS\"",
                "EOF",
                
                f"chmod +x /opt/{service}/health-check.sh"
            ]
            
        elif self.stealth_mode == "low":
            # Low stealth: full monitoring
            commands = [
                f"mkdir -p /opt/{service}",
                
                # Create low stealth configuration
                f"cat > /opt/{service}/low-config.yml << 'EOF'",
                "stealth:",
                "  level: 'low'",
                "  monitoring: 'full_prometheus'",
                "  log_rotation: false",
                "  auto_cleanup: false",
                "  evidence_distribution: 'centralized'",
                "EOF",
                
                # Install node exporter
                "docker run -d --name {service}-exporter \\",
                "  -p 9101:9100 \\",
                "  --restart unless-stopped \\",
                "  prom/node-exporter"
            ]
        
        for cmd in commands:
            if not self.ssh_command(ip, cmd):
                logger.error(f"Failed to execute command on {service} instance: {cmd}")
                return False
        
        return True
    
    def configure_ssl_certificates(self, ip: str, service: str) -> bool:
        """Configure SSL certificates for services"""
        logger.info(f"Configuring SSL certificates for {service} on {ip}")
        
        # Create SSL directory
        commands = [
            f"mkdir -p /etc/ssl/{service}",
            
            # Install certbot if not present
            "command -v certbot >/dev/null 2>&1 || {",
            "  sudo apt update",
            "  sudo apt install -y certbot python3-certbot-nginx",
            "}",
            
            # Create certificate management script
            f"cat > /etc/ssl/{service}/cert-manager.sh << 'EOF'",
            "#!/bin/bash",
            "# SSL certificate management for {service}",
            "DOMAIN_FILE='/etc/ssl/{service}/domain.txt'",
            "if [[ -f \"$DOMAIN_FILE\" ]]; then",
            "  DOMAIN=$(cat \"$DOMAIN_FILE\")",
            "  certbot --nginx -d \"$DOMAIN\" --non-interactive --agree-tos --email admin@${DOMAIN}",
            "  echo '0 12 * * * /usr/bin/certbot renew --quiet' | crontab -",
            "fi",
            "EOF",
            
            f"chmod +x /etc/ssl/{service}/cert-manager.sh"
        ]
        
        for cmd in commands:
            if not self.ssh_command(ip, cmd):
                logger.error(f"Failed to configure SSL for {service}: {cmd}")
                return False
        
        return True
    
    def configure_all_services(self) -> bool:
        """Configure all services with stealth settings"""
        ips = self.get_instance_ips()
        
        if not ips:
            logger.error("No instance IPs found in outputs")
            return False
        
        success = True
        
        # Configure services based on mode
        if self.mode == "primary":
            services = ["mythic", "gophish", "evilginx", "pwndrop"]
        else:
            services = ["mythic"]  # Only Mythic for backup
        
        for service in services:
            if service in ips:
                ip = ips[service]
                logger.info(f"Configuring stealth-enhanced {service} on {ip}")
                
                # Configure SSL certificates first
                if not self.configure_ssl_certificates(ip, service):
                    success = False
                    continue
                
                # Configure the service
                if service == "mythic":
                    success &= self.configure_mythic_stealth(ip)
                else:
                    success &= self.configure_other_service_stealth(ip, service)
            else:
                logger.warning(f"No IP found for service: {service}")
        
        return success
    
    def generate_access_info(self) -> Dict[str, Any]:
        """Generate stealth-enhanced access information"""
        ips = self.get_instance_ips()
        access_info = {
            "provider": self.provider,
            "mode": self.mode,
            "stealth_mode": self.stealth_mode,
            "services": {},
            "timestamp": str(datetime.datetime.now()),
            "stealth_configuration": self._get_stealth_config()
        }
        
        for service, ip in ips.items():
            access_info["services"][service] = {
                "ip": ip,
                "ports": self._get_service_ports(service),
                "urls": self._get_service_urls(service, ip),
                "access_method": self._get_access_method(service),
                "monitoring": self._get_monitoring_info(service)
            }
        
        return access_info
    
    def _get_stealth_config(self) -> Dict[str, Any]:
        """Get stealth configuration details"""
        configs = {
            "high": {
                "monitoring": "minimal",
                "evidence_distribution": "distributed",
                "attack_surface": "minimal",
                "detection_risk": "low",
                "operational_overhead": "low"
            },
            "medium": {
                "monitoring": "basic_health",
                "evidence_distribution": "partial",
                "attack_surface": "moderate",
                "detection_risk": "medium",
                "operational_overhead": "medium"
            },
            "low": {
                "monitoring": "full_centralized",
                "evidence_distribution": "centralized",
                "attack_surface": "large",
                "detection_risk": "high",
                "operational_overhead": "low"
            }
        }
        return configs.get(self.stealth_mode, configs["high"])
    
    def _get_service_ports(self, service: str) -> Dict[str, str]:
        """Get service port mappings"""
        port_mappings = {
            "mythic": {"web": "7443", "agent_http": "80", "agent_https": "443"},
            "gophish": {"web": "443", "admin": "3333"},
            "evilginx": {"proxy": "8080"},
            "pwndrop": {"web": "8080"}
        }
        return port_mappings.get(service, {})
    
    def _get_service_urls(self, service: str, ip: str) -> List[str]:
        """Get service URLs"""
        ports = self._get_service_ports(service)
        urls = []
        
        if service == "mythic":
            urls.append(f"https://{ip}:{ports['web']}")
        elif service == "gophish":
            urls.append(f"https://{ip}:{ports['web']}")
            if self.mode == "primary":
                urls.append(f"http://{ip}:{ports['admin']}")
        elif service == "evilginx":
            urls.append(f"http://{ip}:{ports['proxy']}")
        elif service == "pwndrop":
            urls.append(f"http://{ip}:{ports['proxy']}")
        
        return urls
    
    def _get_access_method(self, service: str) -> str:
        """Get access method based on stealth level"""
        if self.stealth_mode == "high":
            return "ssh_manual_checks_only"
        elif self.stealth_mode == "medium":
            return "ssh_with_basic_health"
        else:
            return "full_monitoring_access"
    
    def _get_monitoring_info(self, service: str) -> Dict[str, Any]:
        """Get monitoring configuration for service"""
        if service == "mythic":
            if self.stealth_mode == "high":
                return {"enabled": True, "type": "container_status_only", "interval": "5m"}
            elif self.stealth_mode == "medium":
                return {"enabled": True, "type": "basic_health", "interval": "30m"}
            else:
                return {"enabled": True, "type": "full_prometheus", "interval": "1m"}
        else:
            if self.stealth_mode == "high":
                return {"enabled": False, "type": "manual_ssh", "interval": "1h"}
            elif self.stealth_mode == "medium":
                return {"enabled": True, "type": "local_health", "interval": "30m"}
            else:
                return {"enabled": True, "type": "node_exporter", "interval": "5m"}

def main():
    parser = argparse.ArgumentParser(description='Stealth-Enhanced Multi-Cloud Service Configuration')
    parser.add_argument('provider', help='Cloud provider (aws, azure, gcp)')
    parser.add_argument('mode', help='Deployment mode (primary, backup)')
    parser.add_argument('outputs_file', help='Terraform outputs JSON file')
    parser.add_argument('--stealth', default='high', choices=['high', 'medium', 'low'],
                       help='Stealth level (default: high)')
    
    args = parser.parse_args()
    
    configurator = StealthServiceConfigurator(
        args.provider, 
        args.mode, 
        args.outputs_file, 
        args.stealth
    )
    
    logger.info(f"Configuring stealth-enhanced services for {args.provider} in {args.mode} mode")
    logger.info(f"Stealth level: {args.stealth}")
    
    if configurator.configure_all_services():
        logger.info("Stealth-enhanced service configuration completed successfully")
        
        # Generate and save access information
        access_info = configurator.generate_access_info()
        output_file = f"access_info_{args.provider}_{args.mode}_stealth.json"
        
        with open(output_file, 'w') as f:
            json.dump(access_info, f, indent=2)
        
        logger.info(f"Stealth access information saved to {output_file}")
        
        # Print summary
        print("\n=== Stealth Configuration Summary ===")
        print(f"Provider: {access_info['provider']}")
        print(f"Mode: {access_info['mode']}")
        print(f"Stealth Level: {access_info['stealth_mode']}")
        print(f"Detection Risk: {access_info['stealth_configuration']['detection_risk']}")
        print(f"Evidence Distribution: {access_info['stealth_configuration']['evidence_distribution']}")
        
        print("\n=== Service Access ===")
        for service, info in access_info["services"].items():
            print(f"\n{service.upper()}:")
            print(f"  IP: {info['ip']}")
            print(f"  URLs: {', '.join(info['urls'])}")
            print(f"  Access: {info['access_method']}")
            print(f"  Monitoring: {info['monitoring']['type']}")
        
        sys.exit(0)
    else:
        logger.error("Stealth-enhanced service configuration failed")
        sys.exit(1)

if __name__ == "__main__":
    import datetime
    main()
