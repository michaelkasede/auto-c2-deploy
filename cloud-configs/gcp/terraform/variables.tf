variable "gcp_project_id" {
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
    mythic    = "e2-standard-2"
    gophish   = "e2-standard-2"
    evilginx  = "e2-standard-2"
    pwndrop   = "e2-small"
    redirector = "e2-small"
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
