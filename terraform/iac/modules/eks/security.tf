##################################################################################################
# Cluster Security Group
#
# Additional security group attached to the EKS control plane ENIs.
# Controls which traffic the API server accepts beyond the EKS-managed cluster SG.
##################################################################################################

resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  description = "EKS cluster control plane additional security group"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Workers → API server (HTTPS)
resource "aws_security_group_rule" "cluster_ingress_nodes_https" {
  type                     = "ingress"
  description              = "Allow worker nodes to reach the cluster API server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
}

# Control plane → workers (kubelet, webhooks on ephemeral ports)
resource "aws_security_group_rule" "cluster_egress_nodes_ephemeral" {
  type                     = "egress"
  description              = "Allow control plane to reach worker kubelets and webhooks"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
}

# Control plane → workers (extension API servers on 443)
resource "aws_security_group_rule" "cluster_egress_nodes_https" {
  type                     = "egress"
  description              = "Allow control plane to reach extension API servers on worker nodes"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
}

##################################################################################################
# Node Security Group
#
# Attached to all EKS worker nodes (via launch template).
# Permits control-plane-to-node, node-to-node, and unrestricted egress.
##################################################################################################

resource "aws_security_group" "node" {
  name_prefix = "${var.cluster_name}-node-"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name                                       = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Node ↔ Node (all traffic — required for pod networking and service mesh)
resource "aws_security_group_rule" "node_ingress_self" {
  type              = "ingress"
  description       = "Allow node-to-node communication"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.node.id
}

# Control plane → nodes (kubelet and workload webhooks)
resource "aws_security_group_rule" "node_ingress_cluster_ephemeral" {
  type                     = "ingress"
  description              = "Allow control plane to reach kubelets and pods on ephemeral ports"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
}

# Control plane → nodes (extension API servers)
resource "aws_security_group_rule" "node_ingress_cluster_https" {
  type                     = "ingress"
  description              = "Allow control plane to reach extension API servers on nodes"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
}

# Nodes → internet (image pulls, DNS, external APIs)
resource "aws_security_group_rule" "node_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic from worker nodes"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
}
