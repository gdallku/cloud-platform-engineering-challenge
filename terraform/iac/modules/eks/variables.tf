##################################################################################################
# Required Variables
##################################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 100
    error_message = "Cluster name must be between 1 and 100 characters."
  }
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must start with 'vpc-'."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for worker nodes and control plane ENIs"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (used by EKS for public-facing load balancers)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least 2 public subnets are required."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^1\\.(2[7-9]|[3-9][0-9])$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format 1.XX (e.g. 1.31)."
  }
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

##################################################################################################
# Optional Variables
##################################################################################################

variable "endpoint_public_access" {
  description = "Whether the EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "bootstrap_instance_type" {
  description = "EC2 instance type for the bootstrap managed node group"
  type        = string
  default     = "t3.small"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*\\.[a-z0-9]+$", var.bootstrap_instance_type))
    error_message = "Instance type must be a valid AWS instance type format (e.g. t3.small, m5.large)."
  }
}
