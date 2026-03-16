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
    
    read -p "Stealth level (high/medium/low) [high]: " stealth_level
    stealth_level=${stealth_level:-high}
    
    read -p "Deployment mode (primary/backup) [primary]: " deployment_mode
    deployment_mode=${deployment_mode:-primary}

    echo ""
    header "DOMAIN CONFIGURATION"
    read -p "Base Domain (e.g., zoom-meeting.duckdns.org): " base_domain
    
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
    echo "  -> Decoy: $base_domain"
    echo "  -> C2 Endpoint: api.$base_domain"
    echo "  -> Mail: mail.$base_domain"
    echo "  -> Login: login.$base_domain"
    echo "  -> Payload: cdn.$base_domain"
    echo ""
    
    read -p "Start engagement? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error "Engagement cancelled"
    fi
    
    # Save engagement configuration
    cat > "$CURRENT_ENGAGEMENT_FILE" << EOF
{
  "engagement_name": "$engagement_name",
  "client_name": "$client_name",
  "start_time": "$(date -Iseconds)",
  "duration_days": $duration,
  "cloud_provider": "$cloud_provider",
  "stealth_level": "$stealth_level",
  "deployment_mode": "$deployment_mode",
  "status": "active",
  "infrastructure": {},
  "access_info": {
    "base_domain": "$base_domain",
    "services": {
      "mythic": { "domain": "api.$base_domain" },
      "gophish": { "domain": "mail.$base_domain" },
      "pwndrop": { "domain": "cdn.$base_domain" },
      "evilginx": { "domain": "login.$base_domain" },
      "redirector": { "domain": "$base_domain" }
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
    export DEPLOYMENT_MODE="$deployment_mode"
    export STEALTH_MODE="$stealth_level"
    export ENVIRONMENT="$engagement_name"
    
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
    
    # Generate access information
    if [[ -f "access_info_${cloud_provider}_${deployment_mode}_stealth.json" ]]; then
        cp "access_info_${cloud_provider}_${deployment_mode}_stealth.json" "$engagement_dir/access.json"
        
        # Update engagement file with access info
        python3 << PYEOF
import json

engagement_file = "$CURRENT_ENGAGEMENT_FILE"
access_file = "$engagement_dir/access.json"

# Load current engagement data
with open(engagement_file, 'r') as f:
    engagement_data = json.load(f)

# Load access data
with open(access_file, 'r') as f:
    access_data = json.load(f)

# Update engagement with access info
engagement_data['access_info'] = access_data

# Save updated engagement data
with open(engagement_file, 'w') as f:
    json.dump(engagement_data, f, indent=2)

print("Engagement updated with access info")
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
$(cat "$engagement_dir/access.json" 2>/dev/null || echo "Access info not available")

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

    if [[ "$redirector_ip" != "NOT_FOUND" ]]; then
        info "Redirector Public IP: $redirector_ip"
        echo "Please update your DuckDNS or Domain records now:"
        echo "  * -> $redirector_ip"
        echo "  @ -> $redirector_ip"
        echo "  api -> $redirector_ip"
        echo "  mail -> $redirector_ip"
        echo "  login -> $redirector_ip"
        echo "  cdn -> $redirector_ip"
    else
        warn "Could not automatically determine Redirector IP. Please check outputs/ folder."
    fi
    
    echo ""
    read -p "Press [Enter] after DNS has been updated and propagated to continue with Ansible configuration..."
    echo ""

    # Run Ansible configuration
    ansible_deployment "$engagement_name"
    
    log "Engagement $engagement_name is now ACTIVE"
    
    echo ""
    header "ENGAGEMENT ACTIVE"
    echo "Access information: $engagement_dir/access.json"
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

# Stop current engagement
stop_engagement() {
    header "STOP ENGAGEMENT"
    
    if [[ ! -f "$CURRENT_ENGAGEMENT_FILE" ]]; then
        error "No active engagement found"
    fi
    
    # Load engagement info
    local engagement_name=$(python3 -c "import json; print(json.load(open('$CURRENT_ENGAGEMENT_FILE')).get('engagement_name', 'unknown'))")
    local cloud_provider=$(python3 -c "import json; print(json.load(open('$CURRENT_ENGAGEMENT_FILE')).get('cloud_provider', 'unknown'))")
    local engagement_dir="$ENGAGEMENTS_DIR/$engagement_name"
    
    if [[ ! -d "$engagement_dir" ]]; then
        error "Engagement directory not found: $engagement_dir"
    fi
    
    echo ""
    echo "Current Engagement:"
    echo "- Name: $engagement_name"
    echo "- Cloud: $cloud_provider"
    echo "- Status: Active"
    echo ""
    
    read -p "Stop engagement and teardown infrastructure? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error "Engagement stop cancelled"
    fi
    
    engagement "Stopping $engagement_name"
    log "Tearing down infrastructure on $cloud_provider"
    
    # Backup data before teardown
    backup_engagement_data "$engagement_name"
    
    # Teardown infrastructure
    cd "$PROJECT_ROOT"
    
    if [[ -d "cloud-configs/$cloud_provider/terraform" ]]; then
        cd "cloud-configs/$cloud_provider/terraform"
        
        if [[ -f "terraform.tfstate" ]]; then
            log "Destroying infrastructure on $cloud_provider..."
            terraform destroy -auto-approve
            
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

engagement_file = "$CURRENT_ENGAGEMENT_FILE"

# Load current engagement data
with open(engagement_file, 'r') as f:
    engagement_data = json.load(f)

# Update engagement status
engagement_data['status'] = 'stopped'
engagement_data['end_time'] = $(date -Iseconds)

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

=== Engagement Summary ===
Duration: $(python3 -c "
import json
with open('$CURRENT_ENGAGEMENT_FILE', 'r') as f:
    data = json.load(f)
    if 'start_time' in data and 'end_time' in data:
        duration = int(data['end_time']) - int(data['start_time'])
        hours = duration // 3600
        minutes = (duration % 3600) // 60
        print(f'{hours}h {minutes}m')
    else:
        print('Unknown')
")
EOF
    
    # Clear current engagement
    mv "$CURRENT_ENGAGEMENT_FILE" "$engagement_dir/engagement.json"
    
    engagement "Engagement $engagement_name stopped"
    log "Infrastructure teardown completed"
    
    echo ""
    header "ENGAGEMENT STOPPED"
    echo "All data backed up to: $engagement_dir"
    echo "Engagement log: $engagement_dir/engagement.log"
    echo "Infrastructure state: $engagement_dir/terraform.tfstate"
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
    
    if 'start_time' in data:
        start_time = datetime.fromtimestamp(int(data['start_time']))
        duration = datetime.now() - start_time
        hours = duration.total_seconds() // 3600
        minutes = (duration.total_seconds() % 3600) // 60
        
        print(f"Status: {status.upper()}")
        print(f"Name: {name}")
        print(f"Client: {client}")
        print(f"Cloud: {cloud}")
        print(f"Stealth: {stealth}")
        print(f"Duration: {int(hours)}h {int(minutes)}m")
        
        if status == 'active':
            print(f"Engagement directory: engagements/{name}")
            print("Access file: engagements/{name}/access.json")
        else:
            print("Engagement is not active")
    
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
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${engagement_name}_backup_${timestamp}.tar.gz"
    
    log "Backing up engagement data..."
    
    # Create backup
    tar -czf "$backup_file" -C "$ENGAGEMENTS_DIR" "$engagement_name"
    
    # Backup current infrastructure state
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
            if [[ -f "$dir/engagement.json" ]]; then
                echo ""
                echo "=== $basename ==="
                python3 << PYEOF
import json
from datetime import datetime

try:
    with open('$dir/engagement.json', 'r') as f:
        data = json.load(f)
    
    name = data.get('engagement_name', 'Unknown')
    client = data.get('client_name', 'Unknown')
    status = data.get('status', 'Unknown')
    cloud = data.get('cloud_provider', 'Unknown')
    stealth = data.get('stealth_level', 'Unknown')
    
    if 'start_time' in data:
        start_time = datetime.fromtimestamp(int(data['start_time']))
        print(f"Client: {client}")
        print(f"Started: {start_time.strftime('%Y-%m-%d %H:%M')}")
        print(f"Cloud: {cloud}")
        print(f"Stealth: {stealth}")
        print(f"Status: {status.upper()}")
        
        if 'end_time' in data:
            end_time = datetime.fromtimestamp(int(data['end_time']))
            print(f"Ended: {end_time.strftime('%Y-%m-%d %H:%M')}")
        else:
            print("Duration: Active")
    
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
    echo "  help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start new engagement (interactive)"
    echo "  $0 --status                  # Check current status"
    echo "  $0 stop                     # Stop current engagement"
    echo "  $0 list                     # List all engagements"
}

# Main function
main() {
    # Setup directories
    setup_directories
    
    # Parse command line arguments
    case "${1:-}" in
        start|"")
            start_engagement
            ;;
        stop|"")
            stop_engagement
            ;;
        --status|status|"")
            check_status
            ;;
        list|"")
            list_engagements
            ;;
        --backup|backup|"")
            if [[ -f "$CURRENT_ENGAGEMENT_FILE" ]]; then
                engagement_name=$(python3 -c "import json; print(json.load(open('$CURRENT_ENGAGEMENT_FILE')).get('engagement_name', 'unknown'))")
                backup_engagement_data "$engagement_name"
            else
                error "No active engagement to backup"
            fi
            ;;
        --help|help|"-h"|"-")
            show_usage
            ;;
        *)
            show_usage
            error "Unknown command: $1"
            ;;
    esac
}

# Run main function
main "$@"
