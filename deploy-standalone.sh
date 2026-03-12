#!/bin/bash

# Multi-Cloud Red Team Infrastructure Deployment
# Standalone deployment - completely separate from Mythic

set -euo pipefail

# Configuration
ENVIRONMENT=${ENVIRONMENT:-"redteam"}
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-"primary"}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }
header() { echo -e "${CYAN}=== $1 ===${NC}"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Interactive cloud provider selection
select_cloud_provider() {
    header "CLOUD PROVIDER SELECTION"
    
    echo "Select cloud provider for deployment:"
    echo "1) AWS (Default) - Primary production deployment"
    echo "2) Azure - Backup or standalone deployment"
    echo "3) GCP - Backup or standalone deployment"
    echo "4) Multi-Cloud - Deploy to all providers (AWS primary, others backup)"
    echo ""
    
    while true; do
        read -p "Enter your choice [1-4]: " choice
        
        case $choice in
            1|"")
                CLOUD_PROVIDER="aws"
                log "Selected: AWS (Default)"
                break
                ;;
            2)
                CLOUD_PROVIDER="azure"
                log "Selected: Azure"
                break
                ;;
            3)
                CLOUD_PROVIDER="gcp"
                log "Selected: GCP"
                break
                ;;
            4)
                CLOUD_PROVIDER="all"
                log "Selected: Multi-Cloud deployment"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1-4."
                ;;
        esac
    done
    
    echo ""
}

# Interactive deployment mode selection
select_deployment_mode() {
    if [[ "$CLOUD_PROVIDER" == "all" ]]; then
        DEPLOYMENT_MODE="primary"
        log "Multi-cloud deployment: Using primary mode for AWS, backup mode for others"
        return
    fi
    
    header "DEPLOYMENT MODE SELECTION"
    
    echo "Select deployment mode:"
    echo "1) Primary - Full production deployment with all services"
    echo "2) Backup - Minimal deployment for failover standby"
    echo ""
    
    while true; do
        read -p "Enter your choice [1-2]: " choice
        
        case $choice in
            1|"")
                DEPLOYMENT_MODE="primary"
                log "Selected: Primary deployment mode"
                break
                ;;
            2)
                DEPLOYMENT_MODE="backup"
                log "Selected: Backup deployment mode"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1-2."
                ;;
        esac
    done
    
    echo ""
}

# Confirm deployment
confirm_deployment() {
    header "DEPLOYMENT CONFIRMATION"
    
    echo "Configuration Summary:"
    echo "- Cloud Provider: $CLOUD_PROVIDER"
    echo "- Deployment Mode: $DEPLOYMENT_MODE"
    echo "- Environment: $ENVIRONMENT"
    echo "- Project Root: $PROJECT_ROOT"
    echo ""
    
    if [[ "$CLOUD_PROVIDER" == "all" ]]; then
        echo "This will deploy:"
        echo "- AWS: Primary deployment (all services)"
        echo "- Azure: Backup deployment (minimal services)"
        echo "- GCP: Backup deployment (minimal services)"
    else
        echo "This will deploy to $CLOUD_PROVIDER in $DEPLOYMENT_MODE mode"
        
        if [[ "$DEPLOYMENT_MODE" == "primary" ]]; then
            echo "- Services: Mythic, GoPhish, Evilginx, Pwndrop"
        else
            echo "- Services: Mythic (backup only)"
        fi
    fi
    
    echo ""
    
    while true; do
        read -p "Continue with deployment? [y/N]: " confirm
        
        case $confirm in
            [Yy]*)
                log "Deployment confirmed"
                break
                ;;
            *)
                error "Deployment cancelled by user"
                ;;
        esac
    done
    
    echo ""
}

# Create directory structure
create_structure() {
    log "Creating multi-cloud deployment structure..."
    
    mkdir -p cloud-configs/{aws,azure,gcp}/{terraform,scripts,templates}
    mkdir -p outputs
    mkdir -p monitoring
    mkdir -p failover
    mkdir -p logs
    
    # Copy templates and scripts
    cp templates/* cloud-configs/*/templates/ 2>/dev/null || true
    cp scripts/* cloud-configs/*/scripts/ 2>/dev/null || true
    
    log "Directory structure created"
}

# Deploy to specified cloud
deploy_to_cloud() {
    local provider="$1"
    local mode="$2"
    
    log "Deploying to $provider in $mode mode..."
    
    cd "cloud-configs/$provider/terraform"
    
    # Check if Terraform files exist
    if [[ ! -f "main.tf" ]]; then
        warn "Terraform configuration not found for $provider"
        log "Generating configuration for $provider..."
        python3 "$PROJECT_ROOT/generate-terraform-config.py" "$provider"
    fi
    
    # Initialize
    terraform init
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
environment = "$ENVIRONMENT"
deployment_mode = "$mode"
admin_ip = "$(curl -s ifconfig.me 2>/dev/null || echo "127.0.0.1")"
EOF
    
    # Plan and apply
    log "Planning deployment to $provider..."
    terraform plan -var-file=terraform.tfvars
    
    log "Applying deployment to $provider..."
    terraform apply -var-file=terraform.tfvars -auto-approve
    
    # Save outputs
    terraform output -json > "../../../outputs/${provider}_${mode}.json"
    
    cd "$PROJECT_ROOT"
    
    log "Deployment to $provider completed successfully"
}

# Configure services
configure_services() {
    local provider="$1"
    local mode="$2"
    
    log "Configuring services on $provider..."
    
    # Check if Python script exists
    if [[ ! -f "$PROJECT_ROOT/configure-services.py" ]]; then
        error "configure-services.py not found"
    fi
    
    python3 "$PROJECT_ROOT/configure-services.py" "$provider" "$mode" "outputs/${provider}_${mode}.json"
    
    log "Service configuration completed for $provider"
}

# Setup monitoring
setup_monitoring() {
    log "Setting up cross-cloud monitoring..."
    
    # Create monitoring configuration
    mkdir -p monitoring
    
    cat > monitoring/cross-cloud-monitor.yaml << 'EOF'
monitoring:
  providers:
    aws:
      cloudwatch:
        metrics: ["CPUUtilization", "NetworkIn", "NetworkOut"]
        alarms: true
        notifications: ["email", "slack"]
        
    azure:
      monitor:
        metrics: ["Percentage CPU", "Network In", "Network Out"]
        alerts: true
        notifications: ["email", "slack"]
        
    gcp:
      monitoring:
        metrics: ["compute.googleapis.com/instance/cpu/utilization"]
        alert_policies: true
        notifications: ["email", "slack"]
        
  health_checks:
    interval: 60
    timeout: 10
    retries: 3
    
  failover:
    auto_trigger: false
    manual_approval: true
    notification_channels: ["email", "slack", "pagerduty"]
    
  logging:
    centralized: true
    retention_days: 30
    encryption: true
EOF
    
    log "Monitoring configuration created"
}

# Generate deployment summary
generate_summary() {
    header "DEPLOYMENT SUMMARY"
    
    echo "Deployment completed successfully!"
    echo ""
    
    # Show access information
    for output_file in outputs/*.json; do
        if [[ -f "$output_file" ]]; then
            provider=$(basename "$output_file" .json | cut -d'_' -f1)
            mode=$(basename "$output_file" .json | cut -d'_' -f2)
            
            echo "=== $provider ($mode) ==="
            
            # Extract IPs from output
            if command -v jq >/dev/null 2>&1; then
                ips=$(jq -r 'to_entries[] | "\(.key): \(.value.value // .value)"' "$output_file" 2>/dev/null || echo "Unable to parse output")
                echo "$ips"
            else
                echo "Output saved to: $output_file"
            fi
            echo ""
        fi
    done
    
    echo "=== Next Steps ==="
    echo "1. Configure DNS failover: python3 update-dns.py --create-config"
    echo "2. Test service health: python3 test-failover.py --scenario service_failure"
    echo "3. Set up monitoring alerts"
    echo "4. Document access procedures"
    echo ""
    
    echo "=== Access Files ==="
    echo "- Service outputs: outputs/"
    echo "- Monitoring config: monitoring/cross-cloud-monitor.yaml"
    echo "- Deployment logs: logs/deployment_$(date +%Y%m%d_%H%M%S).log"
    echo ""
    
    echo "=== Project Structure ==="
    echo "Project root: $PROJECT_ROOT"
    echo "Templates: $PROJECT_ROOT/templates/"
    echo "Scripts: $PROJECT_ROOT/scripts/"
    echo "Configs: $PROJECT_ROOT/cloud-configs/"
}

# Check dependencies
check_dependencies() {
    header "CHECKING DEPENDENCIES"
    
    local missing_deps=()
    
    # Check common dependencies
    command -v terraform >/dev/null 2>&1 || missing_deps+=("terraform")
    command -v python3 >/dev/null 2>&1 || missing_deps+=("python3")
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    
    # Check cloud-specific dependencies based on selection
    case "$CLOUD_PROVIDER" in
        aws|all)
            command -v aws >/dev/null 2>&1 || missing_deps+=("aws-cli")
            ;;
        azure|all)
            command -v az >/dev/null 2>&1 || missing_deps+=("azure-cli")
            ;;
        gcp|all)
            command -v gcloud >/dev/null 2>&1 || missing_deps+=("gcloud-cli")
            ;;
    esac
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
    fi
    
    log "All dependencies satisfied"
}

# Main deployment function
main() {
    header "STANDALONE MULTI-CLOUD RED TEAM INFRASTRUCTURE DEPLOYMENT"
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Interactive selections
    select_cloud_provider
    select_deployment_mode
    confirm_deployment
    
    # Check dependencies
    check_dependencies
    
    # Create structure
    create_structure
    
    # Deploy based on selection
    case "$CLOUD_PROVIDER" in
        all)
            log "Starting multi-cloud deployment..."
            
            # Deploy primary to AWS
            deploy_to_cloud "aws" "primary"
            
            # Deploy backup to Azure
            deploy_to_cloud "azure" "backup"
            
            # Deploy backup to GCP
            deploy_to_cloud "gcp" "backup"
            
            setup_monitoring
            ;;
        aws|azure|gcp)
            log "Starting single-cloud deployment to $CLOUD_PROVIDER..."
            
            deploy_to_cloud "$CLOUD_PROVIDER" "$DEPLOYMENT_MODE"
            setup_monitoring
            ;;
        *)
            error "Unsupported cloud provider: $CLOUD_PROVIDER"
            ;;
    esac
    
    # Generate summary
    generate_summary
    
    log "Deployment process completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted by user"' INT

# Run main function
main "$@"
