#!/usr/bin/env python3

# DNS Update Script for Failover
# Updates DNS records to point to backup infrastructure during failover

import json
import sys
import os
import time
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
import requests

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class DNSUpdater:
    def __init__(self, config_file: str = "dns-config.json"):
        self.config_file = config_file
        self.config = self._load_config()
        
    def _load_config(self) -> Dict[str, Any]:
        """Load DNS configuration"""
        try:
            with open(self.config_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.error(f"DNS configuration file not found: {self.config_file}")
            return {}
        except json.JSONDecodeError:
            logger.error(f"Invalid JSON in DNS configuration file: {self.config_file}")
            return {}
    
    def get_service_ip(self, provider: str, service: str) -> Optional[str]:
        """Get service IP from access information"""
        access_file = f"access_info_{provider}_backup.json"
        if not os.path.exists(access_file):
            access_file = f"access_info_{provider}_primary.json"
        
        if not os.path.exists(access_file):
            logger.error(f"Access file not found for {provider}")
            return None
        
        try:
            with open(access_file, 'r') as f:
                access_info = json.load(f)
            
            return access_info.get("services", {}).get(service, {}).get("ip")
        except Exception as e:
            logger.error(f"Error reading access info: {str(e)}")
            return None
    
    def update_cloudflare_dns(self, domain: str, new_ip: str, record_type: str = "A") -> bool:
        """Update Cloudflare DNS record"""
        try:
            api_token = self.config.get("cloudflare", {}).get("api_token")
            zone_id = self.config.get("cloudflare", {}).get("zone_id")
            
            if not api_token or not zone_id:
                logger.error("Cloudflare configuration incomplete")
                return False
            
            # Get existing record
            headers = {
                "Authorization": f"Bearer {api_token}",
                "Content-Type": "application/json"
            }
            
            # List records to find the record ID
            list_url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records"
            params = {"name": domain, "type": record_type}
            
            response = requests.get(list_url, headers=headers, params=params)
            if response.status_code != 200:
                logger.error(f"Failed to list DNS records: {response.text}")
                return False
            
            records = response.json().get("result", [])
            if not records:
                logger.error(f"DNS record not found for {domain}")
                return False
            
            record_id = records[0]["id"]
            
            # Update record
            update_url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}"
            data = {
                "type": record_type,
                "name": domain,
                "content": new_ip,
                "ttl": 60  # Low TTL for failover
            }
            
            response = requests.put(update_url, headers=headers, json=data)
            if response.status_code == 200:
                logger.info(f"Successfully updated {domain} to {new_ip}")
                return True
            else:
                logger.error(f"Failed to update DNS: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error updating Cloudflare DNS: {str(e)}")
            return False
    
    def update_route53_dns(self, domain: str, new_ip: str, record_type: str = "A") -> bool:
        """Update AWS Route 53 DNS record"""
        try:
            import boto3
            
            zone_id = self.config.get("route53", {}).get("zone_id")
            
            if not zone_id:
                logger.error("Route 53 configuration incomplete")
                return False
            
            client = boto3.client('route53')
            
            # Update record
            response = client.change_resource_record_sets(
                HostedZoneId=zone_id,
                ChangeBatch={
                    'Changes': [
                        {
                            'Action': 'UPSERT',
                            'ResourceRecordSet': {
                                'Name': domain,
                                'Type': record_type,
                                'TTL': 60,
                                'ResourceRecords': [
                                    {
                                        'Value': new_ip
                                    }
                                ]
                            }
                        }
                    ]
                }
            )
            
            if response['ChangeInfo']['Status'] == 'PENDING':
                logger.info(f"Successfully initiated DNS update for {domain} to {new_ip}")
                return True
            else:
                logger.error(f"Failed to update Route 53 DNS: {response}")
                return False
                
        except Exception as e:
            logger.error(f"Error updating Route 53 DNS: {str(e)}")
            return False
    
    def update_azure_dns(self, domain: str, new_ip: str, record_type: str = "A") -> bool:
        """Update Azure DNS record"""
        try:
            from azure.mgmt.dns import DnsManagementClient
            from azure.identity import DefaultAzureCredential
            
            resource_group = self.config.get("azure", {}).get("resource_group")
            zone_name = self.config.get("azure", {}).get("zone_name")
            
            if not resource_group or not zone_name:
                logger.error("Azure DNS configuration incomplete")
                return False
            
            credential = DefaultAzureCredential()
            dns_client = DnsManagementClient(credential, subscription_id="")
            
            # Update record
            record_set = dns_client.record_sets.create_or_update(
                resource_group_name=resource_group,
                zone_name=zone_name,
                relative_record_set_name=domain.split('.')[0],
                record_type=record_type,
                parameters={
                    "ttl": 60,
                    "a_records": [{"ipv4_address": new_ip}]
                }
            )
            
            logger.info(f"Successfully updated Azure DNS for {domain} to {new_ip}")
            return True
            
        except Exception as e:
            logger.error(f"Error updating Azure DNS: {str(e)}")
            return False
    
    def update_dns_record(self, provider: str, service: str, target_provider: str) -> bool:
        """Update DNS record for service to point to backup provider"""
        logger.info(f"Updating DNS for {service} from {provider} to {target_provider}")
        
        # Get service domains from configuration
        service_domains = self.config.get("services", {}).get(service, [])
        if not service_domains:
            logger.error(f"No domains configured for service: {service}")
            return False
        
        # Get new IP from target provider
        new_ip = self.get_service_ip(target_provider, service)
        if not new_ip:
            logger.error(f"Could not get IP for {service} on {target_provider}")
            return False
        
        # Update each domain
        success = True
        for domain in service_domains:
            logger.info(f"Updating {domain} to {new_ip}")
            
            # Try different DNS providers based on configuration
            dns_provider = self.config.get("dns_provider", "cloudflare")
            
            if dns_provider == "cloudflare":
                result = self.update_cloudflare_dns(domain, new_ip)
            elif dns_provider == "route53":
                result = self.update_route53_dns(domain, new_ip)
            elif dns_provider == "azure":
                result = self.update_azure_dns(domain, new_ip)
            else:
                logger.error(f"Unsupported DNS provider: {dns_provider}")
                result = False
            
            success &= result
            
            # Wait between updates to avoid rate limiting
            time.sleep(2)
        
        return success
    
    def verify_dns_update(self, domain: str, expected_ip: str, max_wait: int = 300) -> bool:
        """Verify DNS update has propagated"""
        logger.info(f"Verifying DNS update for {domain} to {expected_ip}")
        
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            try:
                import socket
                ip = socket.gethostbyname(domain)
                
                if ip == expected_ip:
                    logger.info(f"DNS update verified for {domain}: {ip}")
                    return True
                else:
                    logger.info(f"DNS not yet updated for {domain}: {ip} (expected: {expected_ip})")
                    
            except socket.gaierror:
                logger.info(f"DNS not yet resolved for {domain}")
            
            time.sleep(30)  # Wait 30 seconds before checking again
        
        logger.error(f"DNS update verification failed for {domain}")
        return False
    
    def update_all_services(self, provider: str, target_provider: str) -> Dict[str, bool]:
        """Update DNS for all services"""
        logger.info(f"Updating all services from {provider} to {target_provider}")
        
        services = ["mythic", "gophish", "evilginx", "pwndrop"]
        results = {}
        
        for service in services:
            success = self.update_dns_record(provider, service, target_provider)
            results[service] = success
        
        return results
    
    def create_sample_config(self):
        """Create sample DNS configuration file"""
        sample_config = {
            "dns_provider": "cloudflare",
            "services": {
                "mythic": [
                    "mythic.example.com",
                    "c2.example.com"
                ],
                "gophish": [
                    "phish.example.com",
                    "login.example.com"
                ],
                "evilginx": [
                    "evilginx.example.com",
                    "proxy.example.com"
                ],
                "pwndrop": [
                    "files.example.com",
                    "downloads.example.com"
                ]
            },
            "cloudflare": {
                "api_token": "your_cloudflare_api_token",
                "zone_id": "your_zone_id"
            },
            "route53": {
                "zone_id": "your_route53_zone_id"
            },
            "azure": {
                "resource_group": "your_resource_group",
                "zone_name": "your_zone_name"
            }
        }
        
        with open("dns-config.json", 'w') as f:
            json.dump(sample_config, f, indent=2)
        
        logger.info("Sample DNS configuration created: dns-config.json")

def main():
    if len(sys.argv) < 5:
        print("Usage: python3 update-dns.py --provider <provider> --service <service> --target <target_provider>")
        print("Or: python3 update-dns.py --provider <provider> --target <target_provider> --all")
        print("Or: python3 update-dns.py --create-config")
        sys.exit(1)
    
    if sys.argv[1] == "--create-config":
        updater = DNSUpdater()
        updater.create_sample_config()
        return
    
    # Parse arguments
    args = sys.argv[1:]
    provider = None
    service = None
    target_provider = None
    update_all = False
    
    for i, arg in enumerate(args):
        if arg == "--provider" and i + 1 < len(args):
            provider = args[i + 1]
        elif arg == "--service" and i + 1 < len(args):
            service = args[i + 1]
        elif arg == "--target" and i + 1 < len(args):
            target_provider = args[i + 1]
        elif arg == "--all":
            update_all = True
    
    if not provider or not target_provider:
        logger.error("Provider and target provider must be specified")
        sys.exit(1)
    
    if not update_all and not service:
        logger.error("Either --service or --all must be specified")
        sys.exit(1)
    
    updater = DNSUpdater()
    
    if update_all:
        results = updater.update_all_services(provider, target_provider)
        
        print("\n=== DNS Update Results ===")
        for service, success in results.items():
            status = "SUCCESS" if success else "FAILED"
            print(f"{service}: {status}")
        
        # Verify updates
        print("\n=== Verifying DNS Updates ===")
        service_domains = updater.config.get("services", {})
        for service, domains in service_domains.items():
            if domains:
                expected_ip = updater.get_service_ip(target_provider, service)
                if expected_ip:
                    for domain in domains[:1]:  # Verify first domain only
                        verified = updater.verify_dns_update(domain, expected_ip)
                        status = "VERIFIED" if verified else "FAILED"
                        print(f"{domain}: {status}")
    else:
        success = updater.update_dns_record(provider, service, target_provider)
        
        if success:
            # Verify update
            service_domains = updater.config.get("services", {}).get(service, [])
            if service_domains:
                expected_ip = updater.get_service_ip(target_provider, service)
                if expected_ip:
                    verified = updater.verify_dns_update(service_domains[0], expected_ip)
                    status = "VERIFIED" if verified else "FAILED"
                    print(f"DNS update for {service}: {status}")
        else:
            print(f"DNS update for {service}: FAILED")

if __name__ == "__main__":
    main()
