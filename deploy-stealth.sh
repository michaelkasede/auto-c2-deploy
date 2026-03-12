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
            1|"")
                STEALTH_MODE="high"
                stealth "High stealth mode - Minimal monitoring footprint"
                break
                ;;
            2)
                STEALTH_MODE="medium"
                stealth "Medium stealth mode - Basic health checks"
                break
                ;;
            3)
                STEALTH_MODE="low"
                stealth "Low stealth mode - Full monitoring (high visibility)"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1-3."
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
    echo "- Stealth Level: $STEALTH_MODE"
    echo "- Environment: $ENVIRONMENT"
    echo "- Project Root: $PROJECT_ROOT"
    echo ""
    
    # Show deployment plan based on stealth level
    case "$STEALTH_MODE" in
        high)
            echo "Stealth Configuration:"
            echo "- Mythic: Basic container monitoring only"
            echo "- Other Services: Manual health checks via SSH"
            echo "- Monitoring: No centralized collection"
            echo "- Evidence: Distributed across VMs"
            ;;
        medium)
            echo "Stealth Configuration:"
            echo "- Mythic: Basic monitoring + health checks"
            echo "- Other Services: Local node exporters"
            echo "- Monitoring: Distributed with optional aggregation"
            echo "- Evidence: Some centralization"
            ;;
        low)
            echo "Stealth Configuration:"
            echo "- All Services: Full Prometheus/Grafana monitoring"
            echo "- Monitoring: Centralized collection"
            echo "- Evidence: Centralized (high risk)"
            ;;
    esac
    
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
        read -p "Continue with stealth-enhanced deployment? [y/N]: " confirm
        
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
    log "Creating stealth-enhanced deployment structure..."
    
    mkdir -p cloud-configs/{aws,azure,gcp}/{terraform,scripts,templates}
    mkdir -p outputs
    mkdir -p monitoring
    mkdir -p failover
    mkdir -p logs
    mkdir -p ssl-certs
    
    # Copy templates and scripts
    cp templates/* cloud-configs/*/templates/ 2>/dev/null || true
    cp scripts/* cloud-configs/*/scripts/ 2>/dev/null || true
    
    log "Directory structure created"
}

# Generate stealth-enhanced Terraform configuration
generate_stealth_terraform() {
    local provider="$1"
    local mode="$2"
    
    log "Generating stealth-enhanced Terraform configuration for $provider..."
    
    cd "cloud-configs/$provider/terraform"
    
    # Generate base configuration
    python3 "$PROJECT_ROOT/generate-terraform-config.py" "$provider"
    
    # Add stealth enhancements based on level
    case "$STEALTH_MODE" in
        high)
            # Add stealth security groups
            cat >> main.tf << 'EOF'

# Stealth Security Group - Restrictive access
resource "aws_security_group" "stealth" {
  name        = "${var.environment}-stealth-sg"
  description = "Stealth security group with minimal access"
  vpc_id      = aws_vpc.redteam.id
  
  # Only allow specific management IPs
  ingress {
    description = "SSH from management IPs only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip}/32"]
  }
  
  # Block common scanning ports
  ingress {
    description = "Block port scanning"
    from_port   = 0
    to_port     = 20
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    action     = "deny"
  }
  
  tags = {
    Name        = "${var.environment}-stealth-sg"
    Environment = var.environment
    Type        = "Stealth"
  }
}
EOF
            ;;
        medium)
            # Add medium stealth configurations
            cat >> main.tf << 'EOF'

# Medium Stealth Security Group
resource "aws_security_group" "medium_stealth" {
  name        = "${var.environment}-medium-sg"
  description = "Medium stealth security group"
  vpc_id      = aws_vpc.redteam.id
  
  # Allow monitoring from specific sources
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip}/32"]
  }
  
  tags = {
    Name        = "${var.environment}-medium-sg"
    Environment = var.environment
    Type        = "MediumStealth"
  }
}
EOF
            ;;
    esac
    
    cd "$PROJECT_ROOT"
    
    log "Stealth-enhanced configuration generated for $provider"
}

# Deploy to specified cloud with stealth
deploy_to_cloud() {
    local provider="$1"
    local mode="$2"
    
    log "Deploying stealth-enhanced infrastructure to $provider in $mode mode..."
    
    cd "cloud-configs/$provider/terraform"
    
    # Initialize
    terraform init
    
    # Create terraform.tfvars with stealth settings
    cat > terraform.tfvars << EOF
environment = "$ENVIRONMENT"
deployment_mode = "$mode"
admin_ip = "$(curl -s ifconfig.me 2>/dev/null || echo "127.0.0.1")"
stealth_mode = "$STEALTH_MODE"
enable_monitoring = "$([ "$STEALTH_MODE" = "low" ] && echo "true" || echo "false")"
enable_centralized_logging = "$([ "$STEALTH_MODE" = "low" ] && echo "true" || echo "false")"
EOF
    
    # Plan and apply
    log "Planning stealth deployment to $provider..."
    terraform plan -var-file=terraform.tfvars
    
    log "Applying stealth deployment to $provider..."
    terraform apply -var-file=terraform.tfvars -auto-approve
    
    # Save outputs
    terraform output -json > "../../../outputs/${provider}_${mode}.json"
    
    cd "$PROJECT_ROOT"
    
    log "Stealth deployment to $provider completed successfully"
}

# Configure services with stealth settings
configure_services() {
    local provider="$1"
    local mode="$2"
    
    log "Configuring stealth-enhanced services on $provider..."
    
    # Check if Python script exists
    if [[ ! -f "$PROJECT_ROOT/configure-services.py" ]]; then
        error "configure-services.py not found"
    fi
    
    # Pass stealth mode to service configuration
    python3 "$PROJECT_ROOT/configure-services.py" "$provider" "$mode" "outputs/${provider}_${mode}.json" --stealth "$STEALTH_MODE"
    
    log "Stealth service configuration completed for $provider"
}

# Setup stealth monitoring
setup_stealth_monitoring() {
    log "Setting up stealth-enhanced monitoring..."
    
    # Create monitoring configuration based on stealth level
    mkdir -p monitoring
    
    case "$STEALTH_MODE" in
        high)
            cat > monitoring/stealth-monitor.yaml << 'EOF'
monitoring:
  stealth_level: "high"
  mythic:
    enabled: true
    metrics: ["container_status", "agent_callbacks", "resource_usage"]
    scrape_interval: "5m"
    retention: "7d"
  
  other_services:
    enabled: false
    monitoring_method: "manual_ssh"
    check_interval: "1h"
    
  centralized_collection:
    enabled: false
    aggregation_method: "none"
    
  evidence_handling:
    distribution: "distributed"
    encryption: true
    auto_cleanup: true
    cleanup_interval: "24h"
EOF
            ;;
        medium)
            cat > monitoring/stealth-monitor.yaml << 'EOF'
monitoring:
  stealth_level: "medium"
  mythic:
    enabled: true
    metrics: ["container_status", "agent_callbacks", "resource_usage", "health_checks"]
    scrape_interval: "3m"
    retention: "14d"
  
  other_services:
    enabled: true
    monitoring_method: "local_node_exporter"
    check_interval: "30m"
    
  centralized_collection:
    enabled: false
    aggregation_method: "optional_ssh_tunnel"
    
  evidence_handling:
    distribution: "partial"
    encryption: true
    auto_cleanup: true
    cleanup_interval: "48h"
EOF
            ;;
        low)
            cat > monitoring/stealth-monitor.yaml << 'EOF'
monitoring:
  stealth_level: "low"
  mythic:
    enabled: true
    metrics: ["all_metrics"]
    scrape_interval: "1m"
    retention: "30d"
  
  other_services:
    enabled: true
    monitoring_method: "full_prometheus"
    check_interval: "5m"
    
  centralized_collection:
    enabled: true
    aggregation_method: "centralized"
    
  evidence_handling:
    distribution: "centralized"
    encryption: true
    auto_cleanup: false
    cleanup_interval: "never"
EOF
            ;;
    esac
    
    log "Stealth monitoring configuration created"
}

# Generate deployment summary
generate_summary() {
    header "STEALTH-ENHANCED DEPLOYMENT SUMMARY"
    
    echo "Deployment completed successfully!"
    echo ""
    
    # Show stealth configuration
    echo "=== Stealth Configuration ==="
    echo "Stealth Level: $STEALTH_MODE"
    
    case "$STEALTH_MODE" in
        high)
            echo "Monitoring: Minimal (Mythic only)"
            echo "Evidence: Distributed across VMs"
            echo "Attack Surface: Minimal"
            echo "Detection Risk: LOW"
            ;;
        medium)
            echo "Monitoring: Basic health checks"
            echo "Evidence: Partially distributed"
            echo "Attack Surface: Moderate"
            echo "Detection Risk: MEDIUM"
            ;;
        low)
            echo "Monitoring: Full centralized"
            echo "Evidence: Centralized (high risk)"
            echo "Attack Surface: Large"
            echo "Detection Risk: HIGH"
            ;;
    esac
    
    echo ""
    
    # Show service information
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
    echo "1. Configure SSL certificates: ./setup-ssl.sh"
    echo "2. Configure DNS failover: python3 update-dns.py --create-config"
    echo "3. Test service health: python3 test-failover.py --scenario service_failure"
    echo "4. Review stealth configuration: cat monitoring/stealth-monitor.yaml"
    echo ""
    
    echo "=== Access Information ==="
    echo "- Service outputs: outputs/"
    echo "- Monitoring config: monitoring/stealth-monitor.yaml"
    echo "- SSL certificates: ssl-certs/"
    echo "- Deployment logs: logs/deployment_$(date +%Y%m%d_%H%M%S).log"
    echo ""
    
    echo "=== Stealth Guidelines ==="
    echo "• Manual health checks recommended for non-critical services"
    echo "• Rotate SSH keys regularly"
    echo "• Use VPN for all management access"
    echo "• Disable unnecessary monitoring endpoints"
    echo "• Implement log rotation and cleanup"
    echo "• Distribute evidence across VMs"
}

# Check dependencies
check_dependencies() {
    header "CHECKING DEPENDENCIES"
    
    local missing_deps=()
    
    # Check common dependencies
    command -v terraform >/dev/null 2>&1 || missing_deps+=("terraform")
    command -v python3 >/dev/null 2>&1 || missing_deps+=("python3")
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v jq >/dev/null 2>&1 || missing_deps+=("jq")
    
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
    header "STEALTH-ENHANCED MULTI-CLOUD RED TEAM INFRASTRUCTURE DEPLOYMENT"
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Interactive selections
    select_cloud_provider
    select_stealth_level
    select_deployment_mode
    confirm_deployment
    
    # Check dependencies
    check_dependencies
    
    # Create structure
    create_structure
    
    # Deploy based on selection
    case "$CLOUD_PROVIDER" in
        all)
            log "Starting multi-cloud stealth deployment..."
            
            # Deploy primary to AWS
            generate_stealth_terraform "aws" "primary"
            deploy_to_cloud "aws" "primary"
            
            # Deploy backup to Azure
            generate_stealth_terraform "azure" "backup"
            deploy_to_cloud "azure" "backup"
            
            # Deploy backup to GCP
            generate_stealth_terraform "gcp" "backup"
            deploy_to_cloud "gcp" "backup"
            
            setup_stealth_monitoring
            ;;
        aws|azure|gcp)
            log "Starting single-cloud stealth deployment to $CLOUD_PROVIDER..."
            
            generate_stealth_terraform "$CLOUD_PROVIDER" "$DEPLOYMENT_MODE"
            deploy_to_cloud "$CLOUD_PROVIDER" "$DEPLOYMENT_MODE"
            setup_stealth_monitoring
            ;;
        *)
            error "Unsupported cloud provider: $CLOUD_PROVIDER"
            ;;
    esac
    
    # Generate summary
    generate_summary
    
    stealth "Deployment completed with stealth enhancements"
    log "Stealth-enhanced deployment process completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted by user"' INT

# Run main function
main "$@"
