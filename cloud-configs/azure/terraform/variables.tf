variable "azure_region" {
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
    redirector = "Standard_D1s_v2"
  }
}

variable "stealth_mode" {
  description = "Stealth mode level"
  type        = string
  default     = "high"
}

variable "deployment_mode" {
  description = "Deployment mode"
  type        = string
  default     = "primary"
}

variable "enable_monitoring" {
  description = "Enable monitoring services"
  type        = bool
  default     = false
}

variable "enable_centralized_logging" {
  description = "Enable centralized logging"
  type        = bool
  default     = false
}
