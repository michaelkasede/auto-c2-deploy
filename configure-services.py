#!/usr/bin/env python3

# Multi-Cloud Service Configuration Script
# Configures services on deployed infrastructure across different cloud providers

import json
import sys
import os
import subprocess
import logging
from typing import Dict, Any, List

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ServiceConfigurator:
    def __init__(self, provider: str, mode: str, outputs_file: str):
        self.provider = provider.lower()
        self.mode = mode.lower()
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
    
    def ssh_command(self, ip: str, command: str) -> bool:
        """Execute SSH command on remote instance"""
        ssh_key = "~/.ssh/redteam-key"
        ssh_cmd = f"ssh -i {ssh_key} -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@{ip} '{command}'"
        
        try:
            result = subprocess.run(ssh_cmd, shell=True, capture_output=True, text=True, timeout=300)
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
    
    def configure_mythic(self, ip: str) -> bool:
        """Configure Mythic service"""
        logger.info(f"Configuring Mythic on {ip}")
        
        commands = [
            # Wait for system to be ready
            "sleep 30",
            
            # Check if Mythic is already configured
            "if [ ! -f /opt/mythic/mythic-cli ]; then",
            "  echo 'Mythic not found, installing...'",
            "  cd /opt && sudo git clone https://github.com/its-a-feature/Mythic.git",
            "  cd /opt/mythic && sudo make",
            "fi",
            
            # Start Mythic services
            "cd /opt/mythic && sudo ./mythic-cli start",
            
            # Wait for services to be ready
            "sleep 60",
            
            # Check service status
            "docker ps | grep mythic"
        ]
        
        for cmd in commands:
            if not self.ssh_command(ip, cmd):
                logger.error(f"Failed to execute command on Mythic instance: {cmd}")
                return False
        
        return True
    
    def configure_gophish(self, ip: str) -> bool:
        """Configure GoPhish service"""
        logger.info(f"Configuring GoPhish on {ip}")
        
        commands = [
            # Create GoPhish directory
            "mkdir -p /opt/gophish",
            
            # Create docker-compose file
            "cat > /opt/gophish/docker-compose.yml << 'EOF'",
            "version: '3.8'",
            "services:",
            "  gophish:",
            "    image: gophish/gophish:latest",
            "    container_name: gophish",
            "    ports:",
            "      - '443:443'",
            "      - '127.0.0.1:3333:3333'",
            "    volumes:",
            "      - ./data:/opt/gophish/data",
            "      - ./ssl:/opt/gophish/ssl",
            "    restart: unless-stopped",
            "EOF",
            
            # Create directories
            "mkdir -p /opt/gophish/data /opt/gophish/ssl",
            
            # Start GoPhish
            "cd /opt/gophish && docker-compose up -d",
            
            # Wait for startup
            "sleep 30",
            
            # Check status
            "docker ps | grep gophish"
        ]
        
        for cmd in commands:
            if not self.ssh_command(ip, cmd):
                logger.error(f"Failed to execute command on GoPhish instance: {cmd}")
                return False
        
        return True
    
    def configure_evilginx(self, ip: str) -> bool:
        """Configure Evilginx service"""
        logger.info(f"Configuring Evilginx on {ip}")
        
        commands = [
            # Install Go
            "wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz",
            "sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz",
            "echo 'export PATH=\$PATH:/usr/local/go/bin' >> ~/.bashrc",
            "source ~/.bashrc",
            
            # Clone and build Evilginx
            "cd /opt && sudo git clone https://github.com/kgretzky/evilginx2.git",
            "cd /opt/evilginx2 && /usr/local/go/bin/go build -o evilginx",
            
            # Create systemd service
            "sudo tee /etc/systemd/system/evilginx.service > /dev/null << 'EOF'",
            "[Unit]",
            "Description=Evilginx2",
            "After=network.target",
            "",
            "[Service]",
            "Type=simple",
            "User=ubuntu",
            "WorkingDirectory=/opt/evilginx2",
            "ExecStart=/opt/evilginx2/evilginx -p ~/.evilginx",
            "Restart=always",
            "",
            "[Install]",
            "WantedBy=multi-user.target",
            "EOF",
            
            # Start service
            "sudo systemctl enable evilginx",
            "sudo systemctl start evilginx",
            
            # Wait for startup
            "sleep 15",
            
            # Check status
            "sudo systemctl status evilginx --no-pager"
        ]
        
        for cmd in commands:
            if not self.ssh_command(ip, cmd):
                logger.error(f"Failed to execute command on Evilginx instance: {cmd}")
                return False
        
        return True
    
    def configure_pwndrop(self, ip: str) -> bool:
        """Configure Pwndrop service"""
        logger.info(f"Configuring Pwndrop on {ip}")
        
        commands = [
            # Download Pwndrop
            "wget https://github.com/kgretzky/pwndrop/releases/latest/download/pwndrop-linux-x64.tar.gz",
            "tar -xzf pwndrop-linux-x64.tar.gz",
            "sudo mv pwndrop /usr/local/bin/",
            "sudo chmod +x /usr/local/bin/pwndrop",
            
            # Create config directory
            "sudo mkdir -p /etc/pwndrop",
            
            # Initialize Pwndrop
            "cd /etc/pwndrop && sudo /usr/local/bin/pwndrop --init",
            
            # Create systemd service
            "sudo tee /etc/systemd/system/pwndrop.service > /dev/null << 'EOF'",
            "[Unit]",
            "Description=Pwndrop",
            "After=network.target",
            "",
            "[Service]",
            "Type=simple",
            "User=ubuntu",
            "WorkingDirectory=/etc/pwndrop",
            "ExecStart=/usr/local/bin/pwndrop",
            "Restart=always",
            "",
            "[Install]",
            "WantedBy=multi-user.target",
            "EOF",
            
            # Start service
            "sudo systemctl enable pwndrop",
            "sudo systemctl start pwndrop",
            
            # Wait for startup
            "sleep 15",
            
            # Check status
            "sudo systemctl status pwndrop --no-pager"
        ]
        
        for cmd in commands:
            if not self.ssh_command(ip, cmd):
                logger.error(f"Failed to execute command on Pwndrop instance: {cmd}")
                return False
        
        return True
    
    def configure_ssl_certificates(self, ip: str, service: str) -> bool:
        """Configure SSL certificates for services"""
        logger.info(f"Configuring SSL certificates for {service} on {ip}")
        
        # For now, use self-signed certificates
        # In production, use Let's Encrypt or custom certificates
        commands = [
            f"mkdir -p /etc/ssl/{service}",
            "sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\",
            f"  -keyout /etc/ssl/{service}/privkey.pem \\",
            f"  -out /etc/ssl/{service}/fullchain.pem \\",
            "  -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost'"
        ]
        
        for cmd in commands:
            if not self.ssh_command(ip, cmd):
                logger.error(f"Failed to configure SSL for {service}: {cmd}")
                return False
        
        return True
    
    def configure_all_services(self) -> bool:
        """Configure all services based on mode"""
        ips = self.get_instance_ips()
        
        if not ips:
            logger.error("No instance IPs found in outputs")
            return False
        
        success = True
        
        # Configure services based on mode
        if self.mode == "primary":
            # Configure all services in primary mode
            services = ["mythic", "gophish", "evilginx", "pwndrop"]
        else:
            # Configure minimal services in backup mode
            services = ["mythic"]  # Only Mythic for backup
        
        for service in services:
            if service in ips:
                ip = ips[service]
                logger.info(f"Configuring {service} on {ip}")
                
                # Configure SSL certificates first
                if not self.configure_ssl_certificates(ip, service):
                    success = False
                    continue
                
                # Configure the service
                if service == "mythic":
                    success &= self.configure_mythic(ip)
                elif service == "gophish":
                    success &= self.configure_gophish(ip)
                elif service == "evilginx":
                    success &= self.configure_evilginx(ip)
                elif service == "pwndrop":
                    success &= self.configure_pwndrop(ip)
            else:
                logger.warning(f"No IP found for service: {service}")
        
        return success
    
    def generate_access_info(self) -> Dict[str, Any]:
        """Generate access information for configured services"""
        ips = self.get_instance_ips()
        access_info = {
            "provider": self.provider,
            "mode": self.mode,
            "services": {},
            "timestamp": str(datetime.datetime.now())
        }
        
        for service, ip in ips.items():
            access_info["services"][service] = {
                "ip": ip,
                "ports": self._get_service_ports(service),
                "urls": self._get_service_urls(service, ip)
            }
        
        return access_info
    
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

def main():
    if len(sys.argv) != 4:
        print("Usage: python3 configure-services.py <provider> <mode> <outputs_file>")
        sys.exit(1)
    
    provider = sys.argv[1]
    mode = sys.argv[2]
    outputs_file = sys.argv[3]
    
    configurator = ServiceConfigurator(provider, mode, outputs_file)
    
    logger.info(f"Configuring services for {provider} in {mode} mode")
    
    if configurator.configure_all_services():
        logger.info("Service configuration completed successfully")
        
        # Generate and save access information
        access_info = configurator.generate_access_info()
        output_file = f"access_info_{provider}_{mode}.json"
        
        with open(output_file, 'w') as f:
            json.dump(access_info, f, indent=2)
        
        logger.info(f"Access information saved to {output_file}")
        
        # Print summary
        print("\n=== Service Configuration Summary ===")
        for service, info in access_info["services"].items():
            print(f"\n{service.upper()}:")
            print(f"  IP: {info['ip']}")
            print(f"  URLs: {', '.join(info['urls'])}")
        
        sys.exit(0)
    else:
        logger.error("Service configuration failed")
        sys.exit(1)

if __name__ == "__main__":
    import datetime
    main()
