#!/usr/bin/env python3

# Terraform Configuration Generator
# Generates Terraform configurations for different cloud providers

import json
import os
import sys
from datetime import datetime

class TerraformGenerator:
    def __init__(self, provider: str):
        self.provider = provider.lower()
        
    def generate_aws_config(self):
        """Generate AWS Terraform configuration"""
        config = '''terraform {
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

# EC2 Instances
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
'''
        
        return config
    
    def generate_azure_config(self):
        """Generate Azure Terraform configuration"""
        config = '''terraform {
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
'''
        
        return config
    
    def generate_gcp_config(self):
        """Generate GCP Terraform configuration"""
        config = '''terraform {
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
'''
        
        return config
    
    def generate_variables_file(self):
        """Generate variables file for the provider"""
        if self.provider == "aws":
            return '''variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
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
}

variable "admin_ip" {
  description = "Admin IP address for SSH access"
  type        = string
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
'''
        elif self.provider == "azure":
            return '''variable "azure_region" {
  description = "Azure region for deployment"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name"
  type        = string
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
'''
        elif self.provider == "gcp":
            return '''variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "us-east1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_regions" {
  description = "Regions for subnets"
  type        = list(string)
  default     = ["us-east1", "us-east1"]
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "admin_ip" {
  description = "Admin IP address for SSH access"
  type        = string
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
'''
    
    def save_config(self, output_dir: str):
        """Save Terraform configuration to files"""
        os.makedirs(output_dir, exist_ok=True)
        
        # Generate main configuration
        if self.provider == "aws":
            config = self.generate_aws_config()
        elif self.provider == "azure":
            config = self.generate_azure_config()
        elif self.provider == "gcp":
            config = self.generate_gcp_config()
        else:
            raise ValueError(f"Unsupported provider: {self.provider}")
        
        # Save main.tf
        with open(os.path.join(output_dir, "main.tf"), "w") as f:
            f.write(config)
        
        # Save variables.tf
        with open(os.path.join(output_dir, "variables.tf"), "w") as f:
            f.write(self.generate_variables_file())
        
        print(f"Terraform configuration generated for {self.provider}")
        print(f"Files saved to: {output_dir}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 generate-terraform-config.py <provider>")
        print("Supported providers: aws, azure, gcp")
        sys.exit(1)
    
    provider = sys.argv[1].lower()
    
    if provider not in ["aws", "azure", "gcp"]:
        print("Error: Unsupported provider")
        print("Supported providers: aws, azure, gcp")
        sys.exit(1)
    
    generator = TerraformGenerator(provider)
    
    # Get output directory (should be called from cloud-configs/{provider}/terraform)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.dirname(script_dir)  # Go up one level to provider dir
    
    generator.save_config(output_dir)

if __name__ == "__main__":
    main()
