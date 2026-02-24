##################################################################################################
# Cluster Outputs
##################################################################################################

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "The endpoint URL for the EKS Kubernetes API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate data for the cluster CA"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "The OIDC issuer URL for IAM Roles for Service Accounts (IRSA)"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

##################################################################################################
# Security Group Outputs
##################################################################################################

output "cluster_security_group_id" {
  description = "The additional security group ID attached to the EKS control plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "The security group ID attached to the EKS worker nodes"
  value       = aws_security_group.node.id
}

##################################################################################################
# IAM Outputs
##################################################################################################

output "node_role_arn" {
  description = "The ARN of the IAM role assigned to EKS worker nodes"
  value       = aws_iam_role.node.arn
}
