terraform {
  required_providers {
    aws = "~> 6.0"
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
  backend "s3" {
    key    = "iac/infastructure/terraform.tfstate"
    bucket = "cloud-platform-engineering-challenge-tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}
provider "aws" {

  default_tags {
    tags = {
      Environment  = var.environment
      Project      = var.project_name
      ManagedBy    = "Terraform"
      map-migrated = var.map_migrated_tag
    }
  }
}