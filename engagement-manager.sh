#!/bin/bash

# Engagement Lifecycle Management
# Launch and teardown red team infrastructure for engagements

set -euo pipefail

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGAGEMENTS_DIR="$PROJECT_ROOT/engagements"
CURRENT_ENGAGEMENT_FILE="$ENGAGEMENTS_DIR/current.json"
LOGS_DIR="$PROJECT_ROOT/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }
header() { echo -e "${CYAN}=== $1 ===${NC}"; }
engagement() { echo -e "${PURPLE}🎯 ENGAGEMENT: $1${NC}"; }

# Create directories
setup_directories() {
    mkdir -p "$ENGAGEMENTS_DIR"
    mkdir -p "$LOGS_DIR"
    mkdir -p "$PROJECT_ROOT/backups"
}

# Start new engagement
start_engagement() {
    header "START NEW ENGAGEMENT"
    
    # Get engagement details
    read -p "Engagement name (e.g., client-2024-03): " engagement_name
    read -p "Client name: " client_name
    read -p "Duration in days: " duration
    read -p "Cloud provider (aws/azure/gcp) [aws]: " cloud_provider
    cloud_provider=${cloud_provider:-aws}

    if [[ "$cloud_provider" == "azure" ]]; then
        read -p "Azure Region (e.g., centralus, westeurope) [centralus]: " cloud_region
        cloud_region=${cloud_region:-centralus}
    elif [[ "$cloud_provider" == "aws" ]]; then
        read -p "AWS Region: " cloud_region
        if [[ -z "${cloud_region:-}" ]]; then
            error "AWS Region is required"
        fi
    elif [[ "$cloud_provider" == "gcp" ]]; then
        read -p "GCP Region (e.g., us-east1, us-east4) [us-east4]: " cloud_region
        cloud_region=${cloud_region:-us-east4}
    else
        read -p "Cloud Region: " cloud_region
    fi
    
    read -p "Stealth level (high/medium/low) [high]: " stealth_level
    stealth_level=${stealth_level:-high}
    
    read -p "Deployment mode (primary/backup) [primary]: " deployment_mode
    deployment_mode=${deployment_mode:-primary}

    echo ""
    header "DOMAIN CONFIGURATION"
    read -p "Base Domain (e.g., zoom-meeting.duckdns.org): " base_domain
    read -p "Decoy Site URL (e.g., https://wordpress.org): " decoy_site_url
    decoy_site_url=${decoy_site_url:-https://wordpress.org}

    echo ""
    header "OPERATOR ACCESS (ALLOWLIST)"
    default_operator_ip="$(curl -s ifconfig.me 2>/dev/null || echo "")"
    if [[ -n "$default_operator_ip" && "$default_operator_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        default_operator_ip="${default_operator_ip}/32"
    fi
    read -p "Operator source IPs/CIDRs (comma-separated) [${default_operator_ip}]: " operator_allowlist_raw
    operator_allowlist_raw=${operator_allowlist_raw:-$default_operator_ip}
    
    # Confirmation
    echo ""
    echo "Engagement Summary:"
    echo "- Name: $engagement_name"
    echo "- Client: $client_name"
    echo "- Duration: $duration days"
    echo "- Cloud: $cloud_provider"
    echo "- Stealth: $stealth_level"
    echo "- Mode: $deployment_mode"
    echo "- Base Domain: $base_domain"
    echo "- Decoy Site: $decoy_site_url"
    echo "- Operator allowlist: ${operator_allowlist_raw:-NONE}"
    echo "  -> Decoy Frontend: $base_domain"
    echo "  -> C2 Endpoint: api.$base_domain"
    echo "  -> Mail: mail.$base_domain"
    echo "  -> Login: login.$base_domain"
    echo "  -> Payload: cdn.$base_domain"
    echo "  -> Operator Portal: ops.$base_domain"
    echo ""
    
    read -p "Start engagement? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error "Engagement cancelled"
    fi
    
    # Save engagement configuration
    # Convert allowlist string to JSON array
    operator_allowlist_json=$(OPERATOR_ALLOWLIST_RAW="$operator_allowlist_raw" python3 - <<'PYEOF'
import json, os, sys
raw = os.environ.get("OPERATOR_ALLOWLIST_RAW", "").strip()
items = []
for part in raw.split(","):
    part = part.strip()
    if part:
        items.append(part)
print(json.dumps(items))
PYEOF
)

    cat > "$CURRENT_ENGAGEMENT_FILE" << EOF
{
  "engagement_name": "$engagement_name",
  "client_name": "$client_name",
  "start_time": "$(date -Iseconds)",
  "duration_days": $duration,
  "cloud_provider": "$cloud_provider",
  "stealth_level": "$stealth_level",
  "deployment_mode": "$deployment_mode",
  "operator_allowlist": $operator_allowlist_json,
  "status": "active",
  "infrastructure": {},
  "access_info": {
    "base_domain": "$base_domain",
    "decoy_site_url": "$decoy_site_url",
    "services": {
      "mythic": { "domain": "api.$base_domain" },
      "gophish": { "domain": "mail.$base_domain" },
      "pwndrop": { "domain": "cdn.$base_domain" },
      "evilginx": { "domain": "login.$base_domain" },
      "redirector": { "domain": "$base_domain" },
      "operator_portal": { "domain": "ops.$base_domain" }
    }
  }
}
EOF
    
    # Create engagement directory
    local engagement_dir="$ENGAGEMENTS_DIR/$engagement_name"
    mkdir -p "$engagement_dir"
    
    # Start deployment
    engagement "Starting $engagement_name"
    log "Launching infrastructure on $cloud_provider"
    
    cd "$PROJECT_ROOT"
    
    # Set environment variables
    export CLOUD_PROVIDER="$cloud_provider"
    export CLOUD_REGION="$cloud_region"
    export DEPLOYMENT_MODE="$deployment_mode"
    export STEALTH_MODE="$stealth_level"
    export ENVIRONMENT="$engagement_name"
    export OPERATOR_ALLOWLIST="$operator_allowlist_raw"
    
    # Deploy infrastructure
    if [[ -f "deploy-stealth.sh" ]]; then
        ./deploy-stealth.sh
    elif [[ -f "deploy-standalone.sh" ]]; then
        ./deploy-standalone.sh
    else
        error "Deployment script not found"
    fi
    
    # Save deployment outputs
    if [[ -f "outputs/${cloud_provider}_${deployment_mode}.json" ]]; then
        cp "outputs/${cloud_provider}_${deployment_mode}.json" "$engagement_dir/deployment.json"
        
        # Update engagement file with infrastructure info
        python3 << PYEOF
import json
import os

engagement_file = "$CURRENT_ENGAGEMENT_FILE"
deployment_file = "$engagement_dir/deployment.json"

# Load current engagement data
with open(engagement_file, 'r') as f:
    engagement_data = json.load(f)

# Load deployment data
with open(deployment_file, 'r') as f:
    deployment_data = json.load(f)

# Update engagement with deployment info
engagement_data['infrastructure'] = deployment_data

# Save updated engagement data
with open(engagement_file, 'w') as f:
    json.dump(engagement_data, f, indent=2)

print("Engagement updated with deployment info")
PYEOF
    fi
    
    # Create engagement log
    cat > "$engagement_dir/engagement.log" << EOF
Engagement: $engagement_name
Client: $client_name
Started: $(date)
Cloud: $cloud_provider
Stealth: $stealth_level
Mode: $deployment_mode
Duration: $duration days

=== Infrastructure deployed ===
$(cat "$engagement_dir/deployment.json" 2>/dev/null || echo "Deployment info not available")

=== Access Information ===
$(cat "$engagement_dir/current.json" 2>/dev/null || echo "Access info not available")

=== Engagement Timeline ===
$(date): Engagement started
EOF
    
    engagement "Infrastructure deployed successfully"
    
    # Pause for DNS update
    echo ""
    header "ACTION REQUIRED: UPDATE DNS"
    
    # Try to extract the redirector IP from deployment.json
    redirector_ip=$(python3 -c "
import json
import os
try:
    with open('$engagement_dir/deployment.json', 'r') as f:
        data = json.load(f)
        # Check various possible output keys
        ip = data.get('redirector_public_ip', {}).get('value') or \
             data.get('redirector_instance_ip', {}).get('value') or \
             data.get('redirector_ip', {}).get('value', 'NOT_FOUND')
        print(ip)
except:
    print('NOT_FOUND')
")

    # Always prompt for operator confirmation/input (Azure users often copy this from portal).
    if [[ "$redirector_ip" == "NOT_FOUND" ]]; then
        warn "Could not automatically determine Redirector Public IP from deployment outputs."
        redirector_ip=""
    else
        info "Detected Redirector Public IP: $redirector_ip"
    fi

    echo ""
    read -p "Enter Redirector Public IP [${redirector_ip}]: " redirector_ip_input
    redirector_ip_input=${redirector_ip_input:-$redirector_ip}

    if [[ -z "${redirector_ip_input:-}" ]]; then
        warn "Redirector Public IP not provided. Please check outputs/ and update DNS manually."
    else
        redirector_ip="$redirector_ip_input"
        info "Using Redirector Public IP: $redirector_ip"
        echo "Please update your DNS records now (all point to redirector):"
        echo "  * -> $redirector_ip"
        echo "  @ -> $redirector_ip"
        echo "  api -> $redirector_ip"
        echo "  mail -> $redirector_ip"
        echo "  login -> $redirector_ip"
        echo "  cdn -> $redirector_ip"
        echo "  ops -> $redirector_ip"
    fi
    
    echo ""
    read -p "Press [Enter] after DNS has been updated and propagated to continue with Ansible configuration..."
    echo ""

    # Run Ansible configuration
    ansible_deployment "$engagement_name"
    
    log "Engagement $engagement_name is now ACTIVE"
    
    echo ""
    header "ENGAGEMENT ACTIVE"
    echo "Access information: $engagement_dir/current.json"
    echo "Deployment logs: $engagement_dir/engagement.log"
    echo "Management commands:"
    echo "  Check status: $0 --status"
    echo "  Stop engagement: $0 --stop"
    echo "  Backup data: $0 --backup"
}

# Run Ansible deployment
ansible_deployment() {
    local engagement_name="$1"
    header "ANSIBLE CONFIGURATION"
    log "Running Ansible playbooks for $engagement_name..."
    
    if [[ ! -d "ansible" ]]; then
        warn "Ansible directory not found, skipping Ansible configuration"
        return
    fi
    
    # Check if ansible is installed
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        warn "ansible-playbook not found, skipping Ansible configuration"
        return
    fi
    
    cd ansible
    ansible-playbook -i inventory/terraform_inventory.py site.yml
    cd ..
    
    log "Ansible configuration completed"
}

# Update the decoy site URL mid-engagement
update_decoy() {
    header "UPDATE DECOY SITE"
    
    if [[ ! -f "$CURRENT_ENGAGEMENT_FILE" ]]; then
        error "No active engagement found to update"
    fi
    
    read -p "New Decoy Site URL (e.g., https://outlook.com): " new_url
    if [[ -z "$new_url" ]]; then
        error "URL cannot be empty"
    fi
    
    # Update the JSON state
    python3 << PYEOF
import json
with open('$CURRENT_ENGAGEMENT_FILE', 'r') as f:
    data = json.load(f)
data['access_info']['decoy_site_url'] = '$new_url'
with open('$CURRENT_ENGAGEMENT_FILE', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF

    log "Updated decoy URL in state to: $new_url"
    log "Applying changes to Redirector via Ansible..."
    
    cd ansible
    ansible-playbook -i inventory/terraform_inventory.py site.yml --limit redirector --tags update_decoy
    cd ..
    
    engagement "Decoy site updated successfully!"
}

# Stop current engagement
stop_engagement() {
    header "STOP ENGAGEMENT"
    
    if [[ ! -f "$CURRENT_ENGAGEMENT_FILE" ]]; then
        error "No active engagement found"
    fi
    
    # Load engagement info using Python to avoid unbound variable issues
    local engagement_name=$(python3 -c "import json; print(json.load(open('$CURRENT_ENGAGEMENT_FILE')).get('engagement_name', 'unknown'))")
    local cloud_provider=$(python3 -c "import json; print(json.load(open('$CURRENT_ENGAGEMENT_FILE')).get('cloud_provider', 'unknown'))")
    local deployment_mode=$(python3 -c "import json; print(json.load(open('$CURRENT_ENGAGEMENT_FILE')).get('deployment_mode', 'primary'))")
    local engagement_dir="$ENGAGEMENTS_DIR/$engagement_name"
    
    if [[ ! -d "$engagement_dir" ]]; then
        error "Engagement directory not found: $engagement_dir"
    fi
    
    echo ""
    echo "Current Engagement:"
    echo "- Name: $engagement_name"
    echo "- Cloud: $cloud_provider"
    echo "- Mode: $deployment_mode"
    echo "- Status: Active"
    echo ""
    
    read -p "Stop engagement and teardown infrastructure? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error "Engagement stop cancelled"
    fi
    
    engagement "Stopping $engagement_name"
    
    # Backup data before teardown
    backup_engagement_data "$engagement_name"
    
    log "Tearing down infrastructure on $cloud_provider"
    cd "$PROJECT_ROOT"
    
    if [[ -d "cloud-configs/$cloud_provider/terraform" ]]; then
        cd "cloud-configs/$cloud_provider/terraform"
        
        if [[ -f "terraform.tfstate" ]]; then
            log "Destroying infrastructure on $cloud_provider..."
            # Provide necessary variables for destroy to succeed
            terraform destroy -auto-approve \
                -var="environment=$engagement_name" \
                -var="deployment_mode=$deployment_mode" \
                -var="admin_ip=127.0.0.1/32" \
                -var="ssh_public_key_path=$HOME/.ssh/id_rsa.pub"
            
            # Move state file to engagement directory
            mv terraform.tfstate "$engagement_dir/"
            mv terraform.tfstate.backup "$engagement_dir/" 2>/dev/null || true
        else
            warn "No Terraform state found - infrastructure may not be deployed"
        fi
        
        cd "$PROJECT_ROOT"
    else
        warn "Cloud configuration not found for $cloud_provider"
    fi
    
    # Update engagement status
    python3 << PYEOF
import json
from datetime import datetime

engagement_file = "$CURRENT_ENGAGEMENT_FILE"

# Load current engagement data
with open(engagement_file, 'r') as f:
    engagement_data = json.load(f)

# Update engagement status
engagement_data['status'] = 'stopped'
engagement_data['end_time'] = datetime.now().isoformat()

# Save updated engagement data
with open(engagement_file, 'w') as f:
    json.dump(engagement_data, f, indent=2)

print("Engagement marked as stopped")
PYEOF
    
    # Update engagement log
    cat >> "$engagement_dir/engagement.log" << EOF
$(date): Engagement stopped
$(date): Infrastructure teardown completed
$(date): Data backed up
EOF
    
    # Clear current engagement
    mv "$CURRENT_ENGAGEMENT_FILE" "$engagement_dir/engagement.json"
    
    engagement "Engagement $engagement_name stopped"
    log "Infrastructure teardown completed"
    
    echo ""
    header "ENGAGEMENT STOPPED"
    echo "All data backed up to: $engagement_dir"
    echo "Engagement log: $engagement_dir/engagement.log"
}

# Check engagement status
check_status() {
    header "ENGAGEMENT STATUS"
    
    if [[ -f "$CURRENT_ENGAGEMENT_FILE" ]]; then
        # Load engagement info
        python3 << PYEOF
import json
from datetime import datetime

try:
    with open('$CURRENT_ENGAGEMENT_FILE', 'r') as f:
        data = json.load(f)
    
    name = data.get('engagement_name', 'Unknown')
    client = data.get('client_name', 'Unknown')
    status = data.get('status', 'Unknown')
    cloud = data.get('cloud_provider', 'Unknown')
    stealth = data.get('stealth_level', 'Unknown')
    
    print(f"Status: {status.upper()}")
    print(f"Name: {name}")
    print(f"Client: {client}")
    print(f"Cloud: {cloud}")
    print(f"Stealth: {stealth}")
    
    if 'start_time' in data:
        try:
            # Handle ISO format
            start_time = datetime.fromisoformat(data['start_time'].replace('Z', '+00:00'))
            duration = datetime.now().astimezone() - start_time
            hours = duration.total_seconds() // 3600
            minutes = (duration.total_seconds() % 3600) // 60
            print(f"Duration: {int(hours)}h {int(minutes)}m")
        except:
            print(f"Started: {data['start_time']}")
        
        if status == 'active':
            print(f"Engagement directory: engagements/{name}")
    
except Exception as e:
    print(f"Error reading engagement data: {e}")
PYEOF
    else
        info "No active engagement found"
        echo "Available engagements:"
        if [[ -d "$ENGAGEMENTS_DIR" ]]; then
            for dir in "$ENGAGEMENTS_DIR"/*; do
                if [[ -d "$dir" ]]; then
                    basename=$(basename "$dir")
                    if [[ -f "$dir/engagement.json" ]]; then
                        status=$(python3 -c "import json; print(json.load(open('$dir/engagement.json')).get('status', 'unknown'))")
                        echo "  - $basename (Status: $status)"
                    fi
                fi
            done
        fi
    fi
}

# Backup engagement data
backup_engagement_data() {
    local engagement_name="$1"
    local engagement_dir="$ENGAGEMENTS_DIR/$engagement_name"
    local backup_dir="$PROJECT_ROOT/backups"
    
    if [[ ! -d "$engagement_dir" ]]; then
        error "Engagement directory not found: $engagement_dir"
    fi
    
    # Load metadata from current file if available, otherwise from engagement_dir
    local current_file="$CURRENT_ENGAGEMENT_FILE"
    if [[ ! -f "$current_file" ]]; then
        current_file="$engagement_dir/engagement.json"
    fi

    local cloud_provider=$(python3 -c "import json; print(json.load(open('$current_file')).get('cloud_provider', 'unknown'))")
    local deployment_mode=$(python3 -c "import json; print(json.load(open('$current_file')).get('deployment_mode', 'primary'))")

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${engagement_name}_backup_${timestamp}.tar.gz"
    
    log "Backing up engagement data..."
    
    # Create backup
    tar -czf "$backup_file" -C "$ENGAGEMENTS_DIR" "$engagement_name"
    
    # Backup current infrastructure outputs
    if [[ -f "outputs/${cloud_provider}_${deployment_mode}.json" ]]; then
        cp "outputs/${cloud_provider}_${deployment_mode}.json" "$backup_dir/${engagement_name}_deployment_${timestamp}.json"
    fi
    
    log "Backup created: $backup_file"
}

# List past engagements
list_engagements() {
    header "PAST ENGAGEMENTS"
    
    if [[ ! -d "$ENGAGEMENTS_DIR" ]]; then
        info "No engagements directory found"
        return
    fi
    
    echo "Engagements:"
    for dir in "$ENGAGEMENTS_DIR"/*; do
        if [[ -d "$dir" ]]; then
            basename=$(basename "$dir")
            local json_file=""
            if [[ -f "$dir/engagement.json" ]]; then
                json_file="$dir/engagement.json"
            elif [[ -f "$dir/current.json" ]]; then
                json_file="$dir/current.json"
            fi

            if [[ -n "$json_file" ]]; then
                echo ""
                echo "=== $basename ==="
                python3 << PYEOF
import json
from datetime import datetime

try:
    with open('$json_file', 'r') as f:
        data = json.load(f)
    
    client = data.get('client_name', 'Unknown')
    status = data.get('status', 'Unknown')
    cloud = data.get('cloud_provider', 'Unknown')
    stealth = data.get('stealth_level', 'Unknown')
    
    print(f"Client: {client}")
    print(f"Cloud: {cloud}")
    print(f"Status: {status.upper()}")
    
    if 'start_time' in data:
        print(f"Started: {data['start_time']}")
    
except Exception as e:
    print(f"Error reading engagement data: {e}")
PYEOF
            fi
        fi
    done
}

# Show usage
show_usage() {
    echo "Red Team Engagement Lifecycle Management"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start              Start a new engagement"
    echo "  stop               Stop current engagement"
    echo "  status             Check engagement status"
    echo "  list               List past engagements"
    echo "  backup             Backup current engagement data"
    echo "  update-decoy       Change the decoy site URL mid-engagement"
    echo "  help               Show this help"
}

# Main function
main() {
    setup_directories
    
    case "${1:-}" in
        start) start_engagement ;;
        stop) stop_engagement ;;
        status|--status) check_status ;;
        list) list_engagements ;;
        update-decoy) update_decoy ;;
        backup|--backup)
            if [[ -f "$CURRENT_ENGAGEMENT_FILE" ]]; then
                engagement_name=$(python3 -c "import json; print(json.load(open('$CURRENT_ENGAGEMENT_FILE')).get('engagement_name', 'unknown'))")
                backup_engagement_data "$engagement_name"
            else
                error "No active engagement to backup"
            fi
            ;;
        --help|help|"-h") show_usage ;;
        *) show_usage; error "Unknown command: ${1:-none}" ;;
    esac
}

main "$@"
