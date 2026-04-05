terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1" # Frankfurt
  
  default_tags {
    tags = {
      Project     = "FinGuard"
      Environment = "PoC"
      Compliance  = "PCI-DSS-Target"
      ManagedBy   = "Terraform"
    }
  }
}