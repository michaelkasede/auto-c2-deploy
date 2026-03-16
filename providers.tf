terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Azure Provider (Modern 4.x branch)
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.63.0" 
    }

    # AWS Provider (Modern 6.x branch)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.35.0"
    }
  }
}

# --- Azure Provider Configuration ---
provider "azurerm" {
  features {} # Required block for AzureRM
  
  # Uses Environment Variables (ARM_CLIENT_ID, etc.) 
  # set during your Service Principal setup.
}

# --- AWS Provider Configuration ---
provider "aws" {
  region = "us-east-1" # Change to your preferred region for Aegis
  
  # Uses Environment Variables (AWS_ACCESS_KEY_ID, etc.)
  # or local AWS CLI profile.
}