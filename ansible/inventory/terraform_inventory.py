#!/usr/bin/env python3

import json
import os
import sys
import argparse

def get_inventory(engagement_file):
    if not os.path.exists(engagement_file):
        return {"_meta": {"hostvars": {}}}

    try:
        with open(engagement_file, 'r') as f:
            engagement_data = json.load(f)
    except Exception:
        return {"_meta": {"hostvars": {}}}

    infrastructure = engagement_data.get('infrastructure', {})
    stealth_level = engagement_data.get('stealth_level', 'high')
    
    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "vars": {
                "ansible_user": "ubuntu",
                "ansible_ssh_private_key_file": "~/.ssh/redteam-key",
                "ansible_ssh_common_args": "-o StrictHostKeyChecking=no",
                "stealth_level": stealth_level
            }
        }
    }

    services = ["mythic", "gophish", "evilginx", "pwndrop"]
    
    for service in services:
        # Check for both AWS and Azure/GCP output formats
        ip = None
        # Try service_instance_ip (AWS)
        if f"{service}_instance_ip" in infrastructure:
            val = infrastructure[f"{service}_instance_ip"]
            ip = val.get('value') if isinstance(val, dict) else val
        # Try service_public_ip (Azure)
        elif f"{service}_public_ip" in infrastructure:
            val = infrastructure[f"{service}_public_ip"]
            ip = val.get('value') if isinstance(val, dict) else val
            
        if ip:
            if service not in inventory:
                inventory[service] = {"hosts": []}
            inventory[service]["hosts"].append(ip)
            
            # Add hostvars for domains if available in access_info
            access_info = engagement_data.get('access_info', {}).get('services', {}).get(service, {})
            domain = access_info.get('domain', f"{service}.local") # Default if not set
            
            inventory["_meta"]["hostvars"][ip] = {
                "service_name": service,
                "domain": domain
            }

    return inventory

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--host', action='store')
    args = parser.parse_args()

    # Path to the current engagement file
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    engagement_file = os.path.join(project_root, "engagements/current.json")

    if args.list:
        print(json.dumps(get_inventory(engagement_file), indent=2))
    elif args.host:
        # Not implemented as _meta provides all hostvars
        print(json.dumps({}))

if __name__ == "__main__":
    main()
