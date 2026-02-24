##################################################################################################
# Launch Template
#
# Attaches the custom node security group and the EKS-managed cluster SG to every instance.
# Enforces IMDSv2 (required for credential theft mitigation in production).
##################################################################################################

resource "aws_launch_template" "bootstrap" {
  name_prefix = "${var.cluster_name}-bootstrap-${var.environment}-"

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    aws_security_group.node.id,
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.cluster_name}-bootstrap-${var.environment}-node"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-bootstrap-${var.environment}-lt"
  })

  lifecycle {
    create_before_destroy = true
  }
}

##################################################################################################
# Bootstrap Managed Node Group
#
# Minimal, single-node group whose sole purpose is running system workloads (e.g. Karpenter).
# Karpenter will dynamically provision all additional capacity — do NOT add more node groups.
##################################################################################################

resource "aws_eks_node_group" "bootstrap" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-bootstrap-${var.environment}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = [var.bootstrap_instance_type]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.bootstrap.id
    version = aws_launch_template.bootstrap.latest_version
  }

  labels = {
    "node-role" = "bootstrap"
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-bootstrap-${var.environment}-node-group"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
  ]

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }
}
