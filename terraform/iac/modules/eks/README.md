# EKS Module

Production-grade Terraform module that provisions an Amazon EKS cluster from scratch using only native AWS resources.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  VPC                                                                │
│                                                                     │
│  ┌────────────────────────┐    ┌────────────────────────────────┐   │
│  │  Public Subnets        │    │  Private Subnets               │   │
│  │                        │    │                                │   │
│  │  (ELB / Ingress)       │    │  ┌──────────────────────────┐ │   │
│  │                        │    │  │  EKS Control Plane       │ │   │
│  │                        │    │  │  (Managed by AWS)        │ │   │
│  │                        │    │  │                          │ │   │
│  │                        │    │  │  - API Server (private)  │ │   │
│  │                        │    │  │  - etcd (encrypted)      │ │   │
│  │                        │    │  │  - Cluster SG attached   │ │   │
│  │                        │    │  └──────────┬───────────────┘ │   │
│  │                        │    │             │                  │   │
│  │                        │    │             │ SG rules         │   │
│  │                        │    │             │ (443, 1025-65535)│   │
│  │                        │    │             ▼                  │   │
│  │                        │    │  ┌──────────────────────────┐ │   │
│  │                        │    │  │  Bootstrap Node Group    │ │   │
│  │                        │    │  │  (1x t3.small ON_DEMAND) │ │   │
│  │                        │    │  │                          │ │   │
│  │                        │    │  │  label: node-role=       │ │   │
│  │                        │    │  │         bootstrap        │ │   │
│  │                        │    │  │                          │ │   │
│  │                        │    │  │  Purpose: runs Karpenter │ │   │
│  │                        │    │  │  Node SG attached        │ │   │
│  │                        │    │  └──────────────────────────┘ │   │
│  └────────────────────────┘    └────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────┐  ┌───────────────┐  ┌──────────────────────────┐  │
│  │  KMS Key    │  │  CloudWatch   │  │  IAM OIDC Provider       │  │
│  │  (rotation) │  │  Log Group    │  │  (IRSA)                  │  │
│  └─────────────┘  └───────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## What This Module Creates

### 1. EKS Control Plane (`main.tf`)

| Resource | Description |
|---|---|
| `aws_eks_cluster.this` | The EKS cluster itself. Configurable Kubernetes version, private endpoint enabled, public endpoint optional. All five control-plane log types are enabled. |
| `aws_cloudwatch_log_group.cluster` | Pre-created CloudWatch log group at `/aws/eks/<cluster_name>/cluster` with 90-day retention and KMS encryption. Created before the cluster so logs land in a group we control. |
| `aws_iam_openid_connect_provider.cluster` | OIDC identity provider for IRSA. Allows Kubernetes service accounts to assume IAM roles via web identity federation. Thumbprint is extracted dynamically. |

### 2. IAM Roles (`iam.tf`)

| Resource | Description |
|---|---|
| `aws_iam_role.cluster` | IAM role assumed by the EKS service (`eks.amazonaws.com`). Attached policy: `AmazonEKSClusterPolicy`. |
| `aws_iam_role.node` | IAM role assumed by EC2 worker nodes (`ec2.amazonaws.com`). Attached policies: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`. |

Both roles use `aws_iam_policy_document` data sources for the trust policies and reference `data.aws_partition` for portability across AWS partitions (commercial, GovCloud, China).

### 3. Security Groups (`security.tf`)

| Resource | Direction | Ports | Description |
|---|---|---|---|
| `aws_security_group.cluster` | — | — | Additional SG attached to the EKS control plane ENIs |
| `cluster_ingress_nodes_https` | Inbound | 443 | Workers to API server |
| `cluster_egress_nodes_ephemeral` | Outbound | 1025-65535 | Control plane to worker kubelets/webhooks |
| `cluster_egress_nodes_https` | Outbound | 443 | Control plane to extension API servers on nodes |
| `aws_security_group.node` | — | — | SG attached to all worker node instances |
| `node_ingress_self` | Inbound | All | Node-to-node pod networking |
| `node_ingress_cluster_ephemeral` | Inbound | 1025-65535 | Control plane to workers |
| `node_ingress_cluster_https` | Inbound | 443 | Control plane to extension API servers |
| `node_egress_all` | Outbound | All | Unrestricted egress (image pulls, DNS, external APIs) |

All rules use individual `aws_security_group_rule` resources (not inline) so downstream modules can add rules without conflicts.

### 4. KMS Key (`kms.tf`)

| Resource | Description |
|---|---|
| `aws_kms_key.cluster` | Customer-managed KMS key with automatic annual rotation. Used for both Kubernetes secrets envelope encryption and CloudWatch log group encryption. |
| `aws_kms_alias.cluster` | Human-readable alias: `alias/eks/<cluster_name>` |

The key policy grants:
- **Root account** — full key administration
- **EKS cluster role** — encrypt, decrypt, generate data keys, create grants (for secrets)
- **CloudWatch Logs service** — encrypt/decrypt scoped to the cluster's log group ARN

### 5. Bootstrap Node Group (`nodegroup.tf`)

| Resource | Description |
|---|---|
| `aws_launch_template.bootstrap` | Attaches both the EKS-managed cluster SG and the custom node SG. Enforces IMDSv2 (`http_tokens = required`) to mitigate credential theft via SSRF. |
| `aws_eks_node_group.bootstrap` | Single ON_DEMAND node (`t3.small` default). Labeled `node-role=bootstrap`. Placed in private subnets only. |

This node group exists **solely to run Karpenter** (or another node autoscaler). Karpenter will dynamically provision all additional worker capacity. No additional node groups are created by this module.

## File Layout

```
modules/eks/
├── main.tf          # Data sources, locals, EKS cluster, OIDC provider, CloudWatch log group
├── iam.tf           # Cluster IAM role, node IAM role, policy attachments
├── security.tf      # Cluster SG, node SG, all ingress/egress rules
├── kms.tf           # KMS key, alias, key policy
├── nodegroup.tf     # Launch template, bootstrap managed node group
├── variables.tf     # All input variables with validation
├── outputs.tf       # All module outputs
├── versions.tf      # Terraform and provider version constraints
└── README.md        # This file
```

## Input Variables

### Required

| Name | Type | Description |
|---|---|---|
| `cluster_name` | `string` | Name of the EKS cluster (1-100 characters) |
| `environment` | `string` | Environment name. Must be `dev`, `staging`, or `prod` |
| `vpc_id` | `string` | VPC ID (must start with `vpc-`) |
| `private_subnet_ids` | `list(string)` | At least 2 private subnet IDs for worker nodes |
| `public_subnet_ids` | `list(string)` | At least 2 public subnet IDs for load balancers |
| `kubernetes_version` | `string` | Kubernetes version, e.g. `1.31` |
| `tags` | `map(string)` | Tags applied to all resources (default `{}`) |

### Optional

| Name | Type | Default | Description |
|---|---|---|---|
| `endpoint_public_access` | `bool` | `false` | Enable the public API server endpoint |
| `bootstrap_instance_type` | `string` | `t3.small` | EC2 instance type for the bootstrap node group |

## Outputs

| Name | Description |
|---|---|
| `cluster_id` | The ID of the EKS cluster |
| `cluster_name` | The name of the EKS cluster |
| `cluster_endpoint` | The endpoint URL for the Kubernetes API server |
| `cluster_certificate_authority_data` | Base64-encoded CA certificate for kubectl/client configuration |
| `cluster_oidc_issuer_url` | OIDC issuer URL (used for IRSA trust policies) |
| `cluster_security_group_id` | The additional security group attached to the control plane |
| `node_security_group_id` | The security group attached to worker nodes |
| `node_role_arn` | The ARN of the worker node IAM role |

## Usage Example

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name       = "my-cluster"
  environment        = "prod"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = [module.vpc.private_subnet_1_id, module.vpc.private_subnet_2_id]
  public_subnet_ids  = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]
  kubernetes_version = "1.31"

  endpoint_public_access  = false
  bootstrap_instance_type = "t3.small"

  tags = {
    Project = "cloud-platform-engineering-challenge"
  }
}
```

## Security Hardening Summary

| Feature | Implementation |
|---|---|
| Secrets encryption | KMS envelope encryption via `encryption_config` on the cluster |
| Log encryption | CloudWatch log group encrypted with the same KMS key |
| IMDSv2 enforcement | Launch template sets `http_tokens = required` (blocks IMDSv1) |
| Private API endpoint | `endpoint_private_access = true` always; public access is opt-in |
| Least-privilege IAM | Only AWS-managed policies attached; trust policies scoped to specific service principals |
| SG isolation | Explicit per-rule security group resources; no `0.0.0.0/0` ingress |
| Key rotation | KMS key has `enable_key_rotation = true` (annual automatic rotation) |
| IRSA | OIDC provider enables pod-level IAM instead of node-level credentials |

## Prerequisites

- An existing VPC with at least 2 public and 2 private subnets
- Private subnets must have a NAT gateway route to the internet (for image pulls)
- Terraform >= 1.5
- AWS provider >= 5.0
- TLS provider >= 4.0

## What Comes Next

This module intentionally does **not** provision:

- **EKS add-ons** (VPC CNI, CoreDNS, kube-proxy) — these are managed by EKS by default
- **Additional node groups** — Karpenter handles all dynamic capacity after bootstrap
- **Karpenter itself** — deploy via Helm after the cluster is up
- **Ingress controllers, service meshes, monitoring** — layered on separately

The expected workflow after `terraform apply`:

1. Configure `kubectl` using the cluster endpoint and CA data outputs
2. Install Karpenter on the bootstrap node (it has the `node-role=bootstrap` label)
3. Create Karpenter `NodePool` and `EC2NodeClass` resources
4. Karpenter provisions all workload nodes from that point forward
