##################################################################################################
# Data Sources
##################################################################################################

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

##################################################################################################
# Locals
##################################################################################################

locals {
  common_tags = merge(var.tags, {
    Name        = var.cluster_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]
}

##################################################################################################
# CloudWatch Log Group
#
# Created before the cluster so control-plane logs land in a log group we own,
# with a defined retention policy and KMS encryption.
##################################################################################################

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.cluster.arn

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-logs"
  })
}

##################################################################################################
# EKS Cluster
##################################################################################################

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.cluster.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = local.cluster_log_types

  tags = merge(local.common_tags, {
    Name = var.cluster_name
  })

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster,
    aws_kms_key.cluster,
  ]
}

##################################################################################################
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
#
# Enables Kubernetes service accounts to assume IAM roles via web identity federation.
# The thumbprint is extracted dynamically from the cluster's OIDC issuer certificate.
##################################################################################################

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}
