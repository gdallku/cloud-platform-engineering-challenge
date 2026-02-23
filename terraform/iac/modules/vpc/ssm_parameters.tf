# Network SSM Parameters

resource "aws_ssm_parameter" "private_subnet_1" {
  name        = "/${var.project_name}/${var.environment}/private-subnet-1-id"
  description = "Private Subnet 1 (${var.environment})"
  type        = "String"
  value       = aws_subnet.private_subnet_1.id

  depends_on = [aws_subnet.private_subnet_1]
}

resource "aws_ssm_parameter" "private_subnet_2" {
  name        = "/${var.project_name}/${var.environment}/private-subnet-2-id"
  description = "Private Subnet 2 (${var.environment})"
  type        = "String"
  value       = aws_subnet.private_subnet_2.id

  depends_on = [aws_subnet.private_subnet_2]
}

resource "aws_ssm_parameter" "public_subnet_1" {
  name        = "/${var.project_name}/${var.environment}/public-subnet-1-id"
  description = "Public Subnet 1 (${var.environment})"
  type        = "String"
  value       = aws_subnet.public_subnet_1.id

  depends_on = [aws_subnet.public_subnet_1]
}

resource "aws_ssm_parameter" "public_subnet_2" {
  name        = "/${var.project_name}/${var.environment}/public-subnet-2-id"
  description = "Public Subnet 2 (${var.environment})"
  type        = "String"
  value       = aws_subnet.public_subnet_2.id

  depends_on = [aws_subnet.public_subnet_2]
}

resource "aws_ssm_parameter" "vpc_id" {
  name        = "/${var.project_name}/${var.environment}/vpc_id"
  description = "VPC ID (${var.environment})"
  type        = "String"
  value       = aws_vpc.vpc.id
}

resource "aws_ssm_parameter" "private_security_group_id" {
  name        = "/${var.project_name}/${var.environment}/private-security-group-id"
  description = "Private Security Group ID (${var.environment})"
  type        = "String"
  value       = aws_security_group.private_network_sg.id

  depends_on = [aws_security_group.private_network_sg]
}

resource "aws_ssm_parameter" "public_security_group_id" {
  name        = "/${var.project_name}/${var.environment}/public-security-group-id"
  description = "Public Security Group ID (${var.environment})"
  type        = "String"
  value       = aws_security_group.public_network_sg.id

  depends_on = [aws_security_group.public_network_sg]
}
