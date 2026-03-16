#!/bin/bash

# Stealth-Enhanced Multi-Cloud Red Team Infrastructure Deployment
# Hybrid monitoring approach for optimal operational security

set -euo pipefail

# Configuration
ENVIRONMENT=${ENVIRONMENT:-"redteam"}
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-"primary"}
STEALTH_MODE=${STEALTH_MODE:-"high"}

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
stealth() { echo -e "${PURPLE}🔒 STEALTH: $1${NC}"; }

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
            1|"") CLOUD_PROVIDER="aws"; log "Selected: AWS (Default)"; break ;;
            2) CLOUD_PROVIDER="azure"; log "Selected: Azure"; break ;;
            3) CLOUD_PROVIDER="gcp"; log "Selected: GCP"; break ;;
            4) CLOUD_PROVIDER="all"; log "Selected: Multi-Cloud deployment"; break ;;
            *) echo "Invalid choice. Please enter 1-4." ;;
        esac
    done
    echo ""
}

# Stealth level selection
select_stealth_level() {
    header "STEALTH CONFIGURATION"
    echo "Select stealth level:"
    echo "1) HIGH (Recommended) - Minimal monitoring, manual checks"
    echo "2) MEDIUM - Basic health checks only"
    echo "3) LOW - Full monitoring (not recommended for red team)"
    echo ""
    while true; do
        read -p "Enter your choice [1-3]: " choice
        case $choice in
            1|"") STEALTH_MODE="high"; stealth "High stealth mode - Minimal monitoring footprint"; break ;;
            2) STEALTH_MODE="medium"; stealth "Medium stealth mode - Basic health checks"; break ;;
            3) STEALTH_MODE="low"; stealth "Low stealth mode - Full monitoring (high visibility)"; break ;;
            *) echo "Invalid choice. Please enter 1-3." ;;
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
            1|"") DEPLOYMENT_MODE="primary"; log "Selected: Primary deployment mode"; break ;;
            2) DEPLOYMENT_MODE="backup"; log "Selected: Backup deployment mode"; break ;;
            *) echo "Invalid choice. Please enter 1-2." ;;
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
    echo "- Stealth Level: $STEALTH_MODE"
    echo "- Environment: $ENVIRONMENT"
    echo ""
    while true; do
        read -p "Continue with stealth-enhanced deployment? [y/N]: " confirm
        case $confirm in
            [Yy]*) log "Deployment confirmed"; break ;;
            *) error "Deployment cancelled by user" ;;
        esac
    done
    echo ""
}

# Create directory structure
create_structure() {
    log "Creating stealth-enhanced deployment structure..."
    mkdir -p cloud-configs/{aws,azure,gcp}/{terraform,scripts,templates}
    mkdir -p outputs logs ssl-certs monitoring
    cp templates/* cloud-configs/*/templates/ 2>/dev/null || true
    log "Directory structure created"
}

# Generate stealth-enhanced Terraform configuration
generate_stealth_terraform() {
    local provider="$1"
    local mode="$2"
    log "Generating stealth-enhanced Terraform configuration for $provider..."
    cd "cloud-configs/$provider/terraform"
    python3 "$PROJECT_ROOT/generate-terraform-config.py" "$provider"
    
    # AWS-specific stealth security groups (ONLY if provider is AWS)
    if [[ "$provider" == "aws" ]]; then
        if [[ "$STEALTH_MODE" == "high" ]]; then
            cat >> main.tf << 'EOF'
resource "aws_security_group" "stealth" {
  name        = "${var.environment}-stealth-sg"
  vpc_id      = aws_vpc.redteam.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip}/32"]
  }
  tags = { Name = "${var.environment}-stealth-sg", Type = "Stealth" }
}
EOF
        fi
    fi
    cd "$PROJECT_ROOT"
    log "Stealth-enhanced configuration generated for $provider"
}

# Deploy to specified cloud with stealth
deploy_to_cloud() {
    local provider="$1"
    local mode="$2"
    log "Deploying stealth-enhanced infrastructure to $provider in $mode mode..."
    cd "cloud-configs/$provider/terraform"
    terraform init
    cat > terraform.tfvars << EOF
environment = "$ENVIRONMENT"
deployment_mode = "$mode"
admin_ip = "$(curl -s ifconfig.me 2>/dev/null || echo "127.0.0.1")"
azure_region = "${CLOUD_REGION:-centralus}"
stealth_mode = "$STEALTH_MODE"
enable_monitoring = $([ "$STEALTH_MODE" = "low" ] && echo "true" || echo "false")
enable_centralized_logging = $([ "$STEALTH_MODE" = "low" ] && echo "true" || echo "false")
EOF
    terraform plan -var-file=terraform.tfvars
    terraform apply -var-file=terraform.tfvars -auto-approve
    terraform output -json > "../../../outputs/${provider}_${mode}.json"
    cd "$PROJECT_ROOT"
    log "Stealth deployment to $provider completed successfully"
}

# Generate deployment summary
generate_summary() {
    header "STEALTH-ENHANCED DEPLOYMENT SUMMARY"
    echo "Deployment completed successfully!"
}

# Check dependencies
check_dependencies() {
    header "CHECKING DEPENDENCIES"
    local missing_deps=()
    command -v terraform >/dev/null 2>&1 || missing_deps+=("terraform")
    command -v python3 >/dev/null 2>&1 || missing_deps+=("python3")
    command -v jq >/dev/null 2>&1 || missing_deps+=("jq")
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
    fi
    log "All dependencies satisfied"
}

# Main deployment function
main() {
    header "STEALTH-ENHANCED MULTI-CLOUD RED TEAM INFRASTRUCTURE DEPLOYMENT"
    cd "$PROJECT_ROOT"
    if [[ -z "${CLOUD_PROVIDER:-}" ]]; then
        select_cloud_provider
        select_stealth_level
        select_deployment_mode
        confirm_deployment
    fi
    check_dependencies
    create_structure
    case "$CLOUD_PROVIDER" in
        all)
            generate_stealth_terraform "aws" "primary"
            deploy_to_cloud "aws" "primary"
            generate_stealth_terraform "azure" "backup"
            deploy_to_cloud "azure" "backup"
            generate_stealth_terraform "gcp" "backup"
            deploy_to_cloud "gcp" "backup"
            ;;
        aws|azure|gcp)
            generate_stealth_terraform "$CLOUD_PROVIDER" "$DEPLOYMENT_MODE"
            deploy_to_cloud "$CLOUD_PROVIDER" "$DEPLOYMENT_MODE"
            ;;
        *) error "Unsupported cloud provider: $CLOUD_PROVIDER" ;;
    esac
    generate_summary
    stealth "Deployment completed with stealth enhancements"
}

# Handle script interruption
trap 'error "Deployment interrupted by user"' INT

# Run main function
main "$@"
