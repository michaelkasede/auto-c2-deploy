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
    operator_allowlist = engagement_data.get('operator_allowlist', [])
    
    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "vars": {
                "ansible_user": "ubuntu",
                # Prefer SSH_KEY_PATH if set; otherwise use common default key.
                # Note: Ansible expands ~, but we normalize here for clarity.
                "ansible_ssh_private_key_file": os.path.expanduser(
                    os.environ.get("SSH_KEY_PATH", "~/.ssh/id_rsa")
                ),
                "ansible_ssh_common_args": "-o StrictHostKeyChecking=no",
                "stealth_level": stealth_level,
                "operator_allowlist": operator_allowlist
            }
        }
    }

    services = ["mythic", "gophish", "evilginx", "pwndrop", "redirector"]
    
    # Get base domain
    base_domain = engagement_data.get('access_info', {}).get('base_domain', 'example.com')
    
    inventory["all"]["vars"].update({
        "base_domain": base_domain,
        "decoy_domain": base_domain,
        "c2_domain": f"api.{base_domain}",
        "mail_domain": f"mail.{base_domain}",
        "login_domain": f"login.{base_domain}",
        "cdn_domain": f"cdn.{base_domain}"
    })

    # Determine redirector public IP (used as bastion/ProxyJump).
    redirector_public_ip = None
    for key in ("redirector_public_ip", "redirector_instance_ip", "redirector_ip"):
        val = infrastructure.get(key)
        if isinstance(val, dict):
            val = val.get("value")
        if val:
            redirector_public_ip = val
            break

    for service in services:
        # Check for both AWS and Azure/GCP output formats
        ip = None
        # Prefer private IPs for services (redirector is the only public entry point).
        for candidate_key in (
            f"{service}_private_ip",
            f"{service}_instance_ip",
            f"{service}_public_ip",
        ):
            if candidate_key in infrastructure:
                val = infrastructure[candidate_key]
                ip = val.get("value") if isinstance(val, dict) else val
                if ip:
                    break
            
        if ip:
            if service not in inventory:
                inventory[service] = {"hosts": []}
            inventory[service]["hosts"].append(ip)
            
            # Add hostvars for domains if available in access_info
            access_info = engagement_data.get('access_info', {}).get('services', {}).get(service, {})
            domain = access_info.get('domain', f"{service}.local") # Default if not set
            
            hostvars = {
                "service_name": service,
                "domain": domain
            }

            # Use the redirector as a bastion for private services.
            if service != "redirector" and redirector_public_ip:
                ssh_key = inventory["all"]["vars"]["ansible_ssh_private_key_file"]
                hostvars["ansible_ssh_common_args"] = (
                    "-o StrictHostKeyChecking=no "
                    f"-o ProxyJump=ubuntu@{redirector_public_ip} "
                    f"-o IdentityFile={ssh_key}"
                )

            inventory["_meta"]["hostvars"][ip] = hostvars

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
