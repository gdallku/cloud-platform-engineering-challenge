##################################################################################################
# KMS Key for EKS Secrets Encryption and CloudWatch Logs Encryption
##################################################################################################

data "aws_iam_policy_document" "kms" {
  # Account root gets full key management — required for key administration
  statement {
    sid       = "EnableRootAccountAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # EKS cluster role needs encrypt/decrypt for Kubernetes secrets envelope encryption
  statement {
    sid    = "AllowEKSClusterEncryption"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.cluster.arn]
    }
  }

  # CloudWatch Logs service needs access for log group encryption
  statement {
    sid    = "AllowCloudWatchLogsEncryption"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/*"
      ]
    }
  }
}

resource "aws_kms_key" "cluster" {
  description             = "EKS cluster ${var.cluster_name}-${var.environment} — secrets and log encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-eks-kms-${var.environment}"
  })
}

resource "aws_kms_alias" "cluster" {
  name          = "alias/eks/${var.cluster_name}-${var.environment}"
  target_key_id = aws_kms_key.cluster.key_id
}
