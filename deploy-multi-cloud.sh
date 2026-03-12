#!/bin/bash

# Multi-Cloud Red Team Infrastructure Deployment
# Supports AWS, Azure, and GCP deployment with failover capabilities

set -euo pipefail

# Configuration
CLOUD_PROVIDER=${CLOUD_PROVIDER:-"aws"}
ENVIRONMENT=${ENVIRONMENT:-"redteam"}
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-"primary"}  # primary, backup, failover

# Cloud-specific configurations
AWS_REGION=${AWS_REGION:-"us-east-1"}
AZURE_REGION=${AZURE_REGION:-"eastus"}
GCP_REGION=${GCP_REGION:-"us-east1"}

# Common configuration
SSH_KEY_NAME=${SSH_KEY_NAME:-"redteam-key"}
ADMIN_IP=$(curl -s ifconfig.me 2>/dev/null || echo "127.0.0.1")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites for $CLOUD_PROVIDER..."
    
    # Common tools
    command -v docker >/dev/null 2>&1 || error "Docker not installed"
    command -v terraform >/dev/null 2>&1 || error "Terraform not installed"
    
    case "$CLOUD_PROVIDER" in
        aws)
            command -v aws >/dev/null 2>&1 || error "AWS CLI not installed"
            aws sts get-caller-identity >/dev/null 2>&1 || error "AWS credentials not configured"
            ;;
        azure)
            command -v az >/dev/null 2>&1 || error "Azure CLI not installed"
            az account show >/dev/null 2>&1 || error "Azure credentials not configured"
            ;;
        gcp)
            command -v gcloud >/dev/null 2>&1 || error "GCP CLI not installed"
            gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 >/dev/null 2>&1 || error "GCP credentials not configured"
            ;;
        *)
            error "Unsupported cloud provider: $CLOUD_PROVIDER"
            ;;
    esac
    
    log "Prerequisites check passed"
}

# Create cloud-specific directory structure
create_cloud_structure() {
    log "Creating directory structure for $CLOUD_PROVIDER..."
    
    mkdir -p "cloud-configs/$CLOUD_PROVIDER"
    mkdir -p "cloud-configs/$CLOUD_PROVIDER/terraform"
    mkdir -p "cloud-configs/$CLOUD_PROVIDER/scripts"
    mkdir -p "cloud-configs/$CLOUD_PROVIDER/templates"
    
    # Copy common templates
    cp cloud-init-*.sh "cloud-configs/$CLOUD_PROVIDER/templates/" 2>/dev/null || true
    cp configure-multi-operator.sh "cloud-configs/$CLOUD_PROVIDER/scripts/" 2>/dev/null || true
    cp configure-stealth.sh "cloud-configs/$CLOUD_PROVIDER/scripts/" 2>/dev/null || true
}

# Generate AWS configuration
generate_aws_config() {
    log "Generating AWS configuration..."
    
    cat > "cloud-configs/aws/terraform/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Configuration
resource "aws_vpc" "redteam" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.environment}-redteam-vpc"
    Environment = var.environment
    Provider    = "aws"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "redteam" {
  vpc_id = aws_vpc.redteam.id
  
  tags = {
    Name        = "${var.environment}-redteam-igw"
    Environment = var.environment
    Provider    = "aws"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.redteam.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Public"
    Provider    = "aws"
  }
}

# NAT Gateways
resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)
  domain = "vpc"
  
  tags = {
    Name        = "${var.environment}-nat-eip-${count.index + 1}"
    Environment = var.environment
    Provider    = "aws"
  }
}

resource "aws_nat_gateway" "redteam" {
  count = length(var.public_subnet_cidrs)
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name        = "${var.environment}-nat-gw-${count.index + 1}"
    Environment = var.environment
    Provider    = "aws"
  }
  
  depends_on = [aws_internet_gateway.redteam]
}

# Security Groups
resource "aws_security_group" "redteam_base" {
  name        = "${var.environment}-redteam-base-sg"
  description = "Base security group for red team infrastructure"
  vpc_id      = aws_vpc.redteam.id
  
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip}/32"]
  }
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "${var.environment}-redteam-base-sg"
    Environment = var.environment
    Provider    = "aws"
  }
}

# EC2 Instances (simplified example for Mythic)
resource "aws_instance" "mythic" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_types["mythic"]
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.redteam_base.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true
  
  user_data = templatefile("${path.module}/templates/cloud-init-mythic.sh", {
    hostname = "mythic-${var.environment}"
  })
  
  tags = {
    Name        = "${var.environment}-mythic"
    Environment = var.environment
    Service     = "Mythic"
    Role        = "C2"
    Provider    = "aws"
  }
}

# Data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Outputs
output "mythic_instance_ip" {
  description = "Public IP of Mythic instance"
  value       = aws_instance.mythic.public_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.redteam.id
}
EOF

    cat > "cloud-configs/aws/terraform/variables.tf" << EOF
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "$AWS_REGION"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "$ENVIRONMENT"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "ssh_key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "$SSH_KEY_NAME"
}

variable "admin_ip" {
  description = "Admin IP address for SSH access"
  type        = string
  default     = "$ADMIN_IP"
}

variable "instance_types" {
  description = "Instance types for different services"
  type        = map(string)
  default = {
    mythic    = "t3.large"
    gophish   = "t3.medium"
    evilginx  = "t3.medium"
    pwndrop   = "t3.small"
  }
}
EOF
}

# Generate Azure configuration
generate_azure_config() {
    log "Generating Azure configuration..."
    
    cat > "cloud-configs/azure/terraform/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "redteam" {
  name     = "${var.environment}-redteam-rg"
  location = var.azure_region
  
  tags = {
    Environment = var.environment
    Provider    = "azure"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "redteam" {
  name                = "${var.environment}-redteam-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.redteam.location
  resource_group_name = azurerm_resource_group.redteam.name
  
  tags = {
    Environment = var.environment
    Provider    = "azure"
  }
}

# Subnets
resource "azurerm_subnet" "public" {
  count                = length(var.subnet_names)
  name                 = "${var.environment}-public-subnet-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.redteam.name
  virtual_network_name = azurerm_virtual_network.redteam.name
  address_prefixes     = [var.subnet_address_prefixes[count.index]]
}

# Network Security Group
resource "azurerm_network_security_group" "redteam" {
  name                = "${var.environment}-redteam-nsg"
  location            = azurerm_resource_group.redteam.location
  resource_group_name = azurerm_resource_group.redteam.name
  
  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = {
    Environment = var.environment
    Provider    = "azure"
  }
}

# Public IP
resource "azurerm_public_ip" "mythic" {
  name                = "${var.environment}-mythic-pip"
  location            = azurerm_resource_group.redteam.location
  resource_group_name = azurerm_resource_group.redteam.name
  allocation_method   = "Static"
  sku                = "Standard"
  
  tags = {
    Environment = var.environment
    Provider    = "azure"
  }
}

# Network Interface
resource "azurerm_network_interface" "mythic" {
  name                = "${var.environment}-mythic-nic"
  location            = azurerm_resource_group.redteam.location
  resource_group_name = azurerm_resource_group.redteam.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mythic.id
  }
  
  tags = {
    Environment = var.environment
    Provider    = "azure"
  }
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "mythic" {
  name                  = "${var.environment}-mythic-vm"
  location              = azurerm_resource_group.redteam.location
  resource_group_name   = azurerm_resource_group.redteam.name
  network_interface_ids = [azurerm_network_interface.mythic.id]
  size                  = var.vm_sizes["mythic"]
  
  admin_username = "ubuntu"
  admin_ssh_key {
    username   = "ubuntu"
    public_key = file(var.ssh_public_key_path)
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20.04-LTS"
    version   = "latest"
  }
  
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init-mythic.sh", {
    hostname = "mythic-${var.environment}"
  }))
  
  tags = {
    Environment = var.environment
    Service     = "Mythic"
    Role        = "C2"
    Provider    = "azure"
  }
}

# Outputs
output "mythic_public_ip" {
  description = "Public IP of Mythic VM"
  value       = azurerm_public_ip.mythic.ip_address
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.redteam.name
}
EOF

    cat > "cloud-configs/azure/terraform/variables.tf" << EOF
variable "azure_region" {
  description = "Azure region for deployment"
  type        = string
  default     = "$AZURE_REGION"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "$ENVIRONMENT"
}

variable "vnet_address_space" {
  description = "Address space for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_names" {
  description = "Names of subnets"
  type        = list(string)
  default     = ["public1", "public2"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "admin_ip" {
  description = "Admin IP address for SSH access"
  type        = string
  default     = "$ADMIN_IP"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_sizes" {
  description = "VM sizes for different services"
  type        = map(string)
  default = {
    mythic    = "Standard_D4s_v3"
    gophish   = "Standard_D2s_v3"
    evilginx  = "Standard_D2s_v3"
    pwndrop   = "Standard_D1s_v2"
  }
}
EOF
}

# Generate GCP configuration
generate_gcp_config() {
    log "Generating GCP configuration..."
    
    cat > "cloud-configs/gcp/terraform/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# VPC Network
resource "google_compute_network" "redteam" {
  name                    = "${var.environment}-redteam-vpc"
  auto_create_subnetworks = "false"
  
  labels = {
    environment = var.environment
    provider    = "gcp"
  }
}

# Subnets
resource "google_compute_subnetwork" "public" {
  count         = length(var.subnet_regions)
  name          = "${var.environment}-public-subnet-${count.index + 1}"
  ip_cidr_range = var.subnet_cidrs[count.index]
  region        = var.subnet_regions[count.index]
  network       = google_compute_network.redteam.id
  
  labels = {
    environment = var.environment
    provider    = "gcp"
  }
}

# Firewall Rules
resource "google_compute_firewall" "redteam" {
  name    = "${var.environment}-redteam-fw"
  network = google_compute_network.redteam.name
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  
  source_ranges = ["${var.admin_ip}/32", "0.0.0.0/0"]
  
  target_tags = ["redteam"]
  
  labels = {
    environment = var.environment
    provider    = "gcp"
  }
}

# Public IP
resource "google_compute_address" "mythic" {
  name = "${var.environment}-mythic-ip"
  
  labels = {
    environment = var.environment
    provider    = "gcp"
  }
}

# Compute Instance
resource "google_compute_instance" "mythic" {
  name         = "${var.environment}-mythic-vm"
  machine_type = var.machine_types["mythic"]
  zone         = "${var.gcp_region}-a"
  
  tags = ["redteam"]
  
  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 100
      type  = "pd-balanced"
    }
  }
  
  network_interface {
    subnetwork = google_compute_subnetwork.public[0].id
    access_config {
      nat_ip = google_compute_address.mythic.address
    }
  }
  
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = templatefile("${path.module}/templates/cloud-init-mythic.sh", {
      hostname = "mythic-${var.environment}"
    })
  }
  
  labels = {
    environment = var.environment
    service     = "mythic"
    role        = "c2"
    provider    = "gcp"
  }
}

# Data sources
data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}

# Outputs
output "mythic_instance_ip" {
  description = "Public IP of Mythic instance"
  value       = google_compute_address.mythic.address
}

output "instance_name" {
  description = "Instance name"
  value       = google_compute_instance.mythic.name
}
EOF

    cat > "cloud-configs/gcp/terraform/variables.tf" << EOF
variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "$GCP_REGION"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "$ENVIRONMENT"
}

variable "subnet_regions" {
  description = "Regions for subnets"
  type        = list(string)
  default     = ["$GCP_REGION", "$GCP_REGION"]
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "admin_ip" {
  description = "Admin IP address for SSH access"
  type        = string
  default     = "$ADMIN_IP"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "machine_types" {
  description = "Machine types for different services"
  type        = map(string)
  default = {
    mythic    = "e2-standard-4"
    gophish   = "e2-standard-2"
    evilginx  = "e2-standard-2"
    pwndrop   = "e2-standard-1"
  }
}
EOF
}

# Create failover configuration
create_failover_config() {
    log "Creating failover configuration..."
    
    cat > failover-config.yaml << 'EOF'
# Multi-Cloud Failover Configuration
failover:
  primary_provider: "aws"
  backup_providers: ["azure", "gcp"]
  
  health_checks:
    interval: 60  # seconds
    timeout: 10
    retries: 3
    
  triggers:
    - service_unavailable: 5  # minutes
    - network_isolation: true
    - security_incident: true
    - manual_override: false
    
  dns_failover:
    ttl: 60
    health_check_endpoint: "/health"
    expected_status: 200
    
  automation:
    auto_deploy_backup: false
    require_approval: true
    notification_channels: ["email", "slack"]
    
services:
  mythic:
    primary:
      provider: "aws"
      region: "us-east-1"
      instance_type: "t3.large"
      
    backup:
      - provider: "azure"
        region: "eastus"
        vm_size: "Standard_D4s_v3"
      - provider: "gcp"
        region: "us-east1"
        machine_type: "e2-standard-4"
        
    health_check:
      port: 7443
      path: "/health"
      protocol: "https"
      
  gophish:
    primary:
      provider: "aws"
      region: "us-east-1"
      instance_type: "t3.medium"
      
    backup:
      - provider: "azure"
        region: "eastus"
        vm_size: "Standard_D2s_v3"
        
    health_check:
      port: 3333
      path: "/health"
      protocol: "http"
      
  evilginx:
    primary:
      provider: "aws"
      region: "us-east-1"
      instance_type: "t3.medium"
      
    backup:
      - provider: "gcp"
        region: "us-east1"
        machine_type: "e2-standard-2"
        
    health_check:
      port: 8080
      path: "/health"
      protocol: "http"
      
  pwndrop:
    primary:
      provider: "aws"
      region: "us-east-1"
      instance_type: "t3.small"
      
    backup:
      - provider: "azure"
        region: "eastus"
        vm_size: "Standard_D1s_v2"
        
    health_check:
      port: 8080
      path: "/health"
      protocol: "http"

data_replication:
  enabled: true
  sync_interval: 300  # seconds
  encryption: true
  compression: true
  
  backup_locations:
    - provider: "azure"
      storage_account: "redteambackups"
      container: "mythic-data"
    - provider: "gcp"
      bucket: "redteam-backups"
      prefix: "mythic-data/"
      
security:
  isolation:
    network_level: true
    credential_level: true
    data_level: true
    
  incident_response:
    auto_isolate: true
    evidence_preservation: true
    notification_required: true
    
monitoring:
  centralized: true
  log_aggregation: true
  alerting:
    critical: ["immediate"]
    warning: ["5_minutes"]
    info: ["hourly"]
EOF
}

# Create deployment orchestration script
create_orchestration_script() {
    log "Creating deployment orchestration script..."
    
    cat > deploy-multi-cloud.sh << 'EOF'
#!/bin/bash

# Multi-Cloud Deployment Orchestration
# Supports automated deployment across AWS, Azure, and GCP

set -euo pipefail

# Configuration
PRIMARY_PROVIDER=${PRIMARY_PROVIDER:-"aws"}
BACKUP_PROVIDERS=${BACKUP_PROVIDERS:-"azure,gcp"}
ENVIRONMENT=${ENVIRONMENT:-"redteam"}
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-"primary"}  # primary, backup, failover

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }

# Deploy to specified cloud provider
deploy_to_cloud() {
    local provider="$1"
    local mode="$2"
    
    log "Deploying to $provider in $mode mode..."
    
    cd "cloud-configs/$provider/terraform"
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
environment = "$ENVIRONMENT"
deployment_mode = "$mode"
EOF
    
    # Plan and apply
    terraform plan -var-file=terraform.tfvars
    terraform apply -var-file=terraform.tfvars -auto-approve
    
    # Capture outputs
    terraform output -json > "../../outputs/${provider}_${mode}.json"
    
    cd ../../..
    
    log "Deployment to $provider completed"
}

# Deploy primary infrastructure
deploy_primary() {
    log "Deploying primary infrastructure to $PRIMARY_PROVIDER..."
    
    mkdir -p outputs
    deploy_to_cloud "$PRIMARY_PROVIDER" "primary"
    
    # Configure services on primary
    ./configure-services.sh "$PRIMARY_PROVIDER" "primary"
    
    log "Primary infrastructure deployment completed"
}

# Deploy backup infrastructure
deploy_backup() {
    IFS=',' read -ra PROVIDERS <<< "$BACKUP_PROVIDERS"
    
    for provider in "${PROVIDERS[@]}"; do
        provider=$(echo "$provider" | xargs) # trim whitespace
        log "Deploying backup infrastructure to $provider..."
        
        deploy_to_cloud "$provider" "backup"
        
        # Configure minimal services on backup
        ./configure-services.sh "$provider" "backup"
    done
    
    log "Backup infrastructure deployment completed"
}

# Configure services on deployed infrastructure
configure_services() {
    local provider="$1"
    local mode="$2"
    
    log "Configuring services on $provider ($mode mode)..."
    
    # Get instance IPs from outputs
    local outputs_file="outputs/${provider}_${mode}.json"
    
    if [[ -f "$outputs_file" ]]; then
        # Extract IPs and configure services
        python3 configure-services.py "$provider" "$mode" "$outputs_file"
    else
        warn "Output file not found: $outputs_file"
    fi
}

# Setup monitoring and health checks
setup_monitoring() {
    log "Setting up monitoring and health checks..."
    
    # Create monitoring configuration
    cat > monitoring-config.yaml << 'EOM'
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
EOM
    
    # Deploy monitoring agents
    ./deploy-monitoring.sh
    
    log "Monitoring setup completed"
}

# Test failover capabilities
test_failover() {
    log "Testing failover capabilities..."
    
    # Create test scenarios
    python3 test-failover.py --scenario "service_failure"
    python3 test-failover.py --scenario "network_isolation"
    python3 test-failover.py --scenario "security_incident"
    
    log "Failover testing completed"
}

# Generate deployment report
generate_report() {
    log "Generating deployment report..."
    
    cat > deployment-report.md << EOF
# Multi-Cloud Red Team Infrastructure Deployment Report

## Deployment Summary
- **Primary Provider**: $PRIMARY_PROVIDER
- **Backup Providers**: $BACKUP_PROVIDERS
- **Environment**: $ENVIRONMENT
- **Deployment Mode**: $DEPLOYMENT_MODE
- **Timestamp**: $(date)

## Infrastructure Status

### Primary Infrastructure ($PRIMARY_PROVIDER)
EOF

    # Add primary infrastructure details
    if [[ -f "outputs/${PRIMARY_PROVIDER}_primary.json" ]]; then
        python3 generate-report.py "$PRIMARY_PROVIDER" "primary" >> deployment-report.md
    fi
    
    # Add backup infrastructure details
    IFS=',' read -ra PROVIDERS <<< "$BACKUP_PROVIDERS"
    for provider in "${PROVIDERS[@]}"; do
        provider=$(echo "$provider" | xargs)
        echo "### Backup Infrastructure ($provider)" >> deployment-report.md
        
        if [[ -f "outputs/${provider}_backup.json" ]]; then
            python3 generate-report.py "$provider" "backup" >> deployment-report.md
        fi
    done
    
    cat >> deployment-report.md << 'EOF'

## Access Information
- SSH keys are located in `./operator-keys/`
- Service URLs are available in respective output files
- Monitoring dashboard: [Link to dashboard]

## Next Steps
1. Verify all services are running
2. Test connectivity and functionality
3. Configure SSL certificates
4. Set up monitoring alerts
5. Conduct failover testing

## Emergency Procedures
1. **Service Failure**: Check monitoring dashboard
2. **Failover Required**: Run `./initiate-failover.sh`
3. **Security Incident**: Isolate affected provider
4. **Complete Outage**: Deploy to all backup providers

---
*Report generated on $(date)*
EOF
    
    log "Deployment report generated: deployment-report.md"
}

# Main execution
main() {
    log "Starting multi-cloud deployment orchestration..."
    
    # Validate configuration
    if [[ ! -f "failover-config.yaml" ]]; then
        error "Failover configuration not found"
    fi
    
    case "$DEPLOYMENT_MODE" in
        primary)
            deploy_primary
            setup_monitoring
            ;;
        backup)
            deploy_backup
            setup_monitoring
            ;;
        failover)
            deploy_primary
            deploy_backup
            setup_monitoring
            test_failover
            ;;
        full)
            deploy_primary
            deploy_backup
            setup_monitoring
            test_failover
            ;;
        *)
            error "Invalid deployment mode: $DEPLOYMENT_MODE"
            ;;
    esac
    
    generate_report
    
    log "Multi-cloud deployment orchestration completed!"
}

# Run main function
main "$@"
EOF
    
    chmod +x deploy-multi-cloud.sh
}

# Create failover initiation script
create_failover_script() {
    log "Creating failover initiation script..."
    
    cat > initiate-failover.sh << 'EOF'
#!/bin/bash

# Failover Initiation Script
# Automates failover from primary to backup infrastructure

set -euo pipefail

FAILOVER_REASON=${FAILOVER_REASON:-"manual"}
TARGET_PROVIDER=${TARGET_PROVIDER:-""}
SERVICE_AFFECTED=${SERVICE_AFFECTED:-"all"}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }

# Validate failover conditions
validate_failover() {
    log "Validating failover conditions..."
    
    # Check if failover is already in progress
    if [[ -f ".failover-in-progress" ]]; then
        error "Failover already in progress"
    fi
    
    # Check backup infrastructure status
    python3 check-backup-status.py
    
    # Create failover lock
    touch .failover-in-progress
    
    log "Failover validation completed"
}

# Execute failover
execute_failover() {
    local provider="$1"
    local service="$2"
    
    log "Executing failover to $provider for service: $service"
    
    # Update DNS records
    python3 update-dns.py --provider "$provider" --service "$service"
    
    # Start backup services
    python3 start-services.py --provider "$provider" --service "$service"
    
    # Verify service health
    python3 verify-health.py --provider "$provider" --service "$service"
    
    log "Failover to $provider completed"
}

# Notify stakeholders
notify_stakeholders() {
    local provider="$1"
    local reason="$2"
    
    log "Notifying stakeholders..."
    
    # Send notifications
    python3 send-notification.py \
        --type "failover" \
        --provider "$provider" \
        --reason "$reason" \
        --channels "email,slack,pagerduty"
    
    log "Stakeholder notifications sent"
}

# Update monitoring
update_monitoring() {
    local provider="$1"
    
    log "Updating monitoring configuration..."
    
    # Update monitoring targets
    python3 update-monitoring.py --provider "$provider"
    
    # Update alerting rules
    python3 update-alerts.py --provider "$provider"
    
    log "Monitoring configuration updated"
}

# Document failover
document_failover() {
    local provider="$1"
    local reason="$2"
    
    log "Documenting failover..."
    
    cat >> failover-log.md << EOF
## Failover Event - $(date)
- **Target Provider**: $provider
- **Affected Services**: $SERVICE_AFFECTED
- **Reason**: $reason
- **Initiated By**: $(whoami)
- **Timestamp**: $(date '+%Y-%m-%d %H:%M:%S UTC')

### Actions Taken
1. Validated failover conditions
2. Executed failover procedures
3. Updated DNS records
4. Verified service health
5. Notified stakeholders
6. Updated monitoring

### Status
- **Primary Provider**: Isolated
- **Backup Provider**: Active
- **Services**: Operational

### Next Steps
1. Monitor backup infrastructure
2. Investigate primary failure
3. Plan recovery procedures
4. Update documentation

EOF
    
    log "Failover documented"
}

# Main execution
main() {
    log "Initiating failover procedures..."
    
    validate_failover
    
    if [[ -z "$TARGET_PROVIDER" ]]; then
        error "Target provider not specified. Use TARGET_PROVIDER environment variable."
    fi
    
    execute_failover "$TARGET_PROVIDER" "$SERVICE_AFFECTED"
    notify_stakeholders "$TARGET_PROVIDER" "$FAILOVER_REASON"
    update_monitoring "$TARGET_PROVIDER"
    document_failover "$TARGET_PROVIDER" "$FAILOVER_REASON"
    
    # Remove failover lock
    rm -f .failover-in-progress
    
    log "Failover procedures completed successfully!"
}

# Run main function
main "$@"
EOF
    
    chmod +x initiate-failover.sh
}

# Main execution
main() {
    log "Starting multi-cloud red team infrastructure setup..."
    
    check_prerequisites
    create_cloud_structure
    
    case "$CLOUD_PROVIDER" in
        aws)
            generate_aws_config
            ;;
        azure)
            generate_azure_config
            ;;
        gcp)
            generate_gcp_config
            ;;
        all)
            generate_aws_config
            generate_azure_config
            generate_gcp_config
            ;;
        *)
            error "Unsupported cloud provider: $CLOUD_PROVIDER"
            ;;
    esac
    
    create_failover_config
    create_orchestration_script
    create_failover_script
    
    log "Multi-cloud infrastructure setup completed!"
    
    echo ""
    log "Directory structure created:"
    tree cloud-configs/ 2>/dev/null || find cloud-configs/ -type f
    
    echo ""
    log "Next steps:"
    echo "1. Configure cloud credentials for each provider"
    echo "2. Customize variables in cloud-configs/*/terraform/variables.tf"
    echo "3. Run deployment: ./deploy-multi-cloud.sh"
    echo "4. Configure monitoring and failover: ./setup-monitoring.sh"
    echo "5. Test failover: ./test-failover.sh"
}

# Run main function
main "$@"
