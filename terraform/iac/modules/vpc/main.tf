data "aws_availability_zones" "available" {
  state = "available"
}

##################################################################################################
#  VPC
##################################################################################################

resource "aws_vpc" "vpc" {
  cidr_block           = "${var.cidr}.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
  }
}

##################################################################################################
# Subnets
##################################################################################################

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.cidr}.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-public-subnet-1-${var.environment}"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.cidr}.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-public-subnet-2-${var.environment}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.cidr}.4.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-private-subnet-1-${var.environment}"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.cidr}.5.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-private-subnet-2-${var.environment}"
  }
}


##################################################################################################
# Internet Gateway
##################################################################################################

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-internet-gw-${var.environment}"
  }
}

##################################################################################################
# NAT Gateway
##################################################################################################

resource "aws_eip" "nat_gateway_public_ip" {

  tags = {
    Name        = "${var.project_name}-nat-eip-${var.environment}"
    Owner       = var.project_name
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_public_ip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Owner       = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_eip.nat_gateway_public_ip]
}

##################################################################################################
# NAT Routing
##################################################################################################

resource "aws_route_table" "nat_route" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name        = "${var.project_name}-private-network-${var.environment}"
    Owner       = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_nat_gateway.nat_gateway]
}

resource "aws_route_table_association" "nat_subnet_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.nat_route.id
}

resource "aws_route_table_association" "nat_subnet_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.nat_route.id
}

##################################################################################################
# Internet Routing
##################################################################################################

resource "aws_default_route_table" "vpc_internet_route" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }

  tags = {
    Name        = "${var.project_name}-default-route-table-${var.environment}"
    Owner       = var.project_name
    Environment = var.environment
  }
}

resource "aws_route_table_association" "internet_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_default_route_table.vpc_internet_route.id
}

resource "aws_route_table_association" "internet_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_default_route_table.vpc_internet_route.id
}

##################################################################################################
# Security Groups
##################################################################################################

resource "aws_security_group" "public_network_sg" {
  name        = "${var.project_name}-public-network-sg-${var.environment}"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = toset(var.public_ingress_ports)
    content {
      description      = "Allow traffic to VPC"
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.project_name}-public-network-sg-${var.environment}"
    Owner       = var.project_name
    Environment = var.environment
  }
}

resource "aws_security_group" "private_network_sg" {
  name        = "${var.project_name}-private-network-sg-${var.environment}"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = toset(var.private_ingress_ports)
    content {
      description      = "Allow traffic to VPC"
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = [aws_vpc.vpc.cidr_block]
    }
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "private-network-sg-${var.environment}"
    Owner       = var.project_name
    Environment = var.environment
  }

}

##################################################################################################
# VPC Logging
##################################################################################################

resource "aws_iam_role" "vpc_logging" {
  name = "${var.project_name}-vpc-logging-role-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "vpc_logging_policy" {
  name = "${var.project_name}-vpc-logging-policy-${var.environment}"
  role = aws_iam_role.vpc_logging.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "vpc_logs" {
  name              = "${var.project_name}-vpc-logs-${var.environment}"
  retention_in_days = var.log_retention
}

resource "aws_flow_log" "project_name_vpc_log_flow" {
  iam_role_arn    = aws_iam_role.vpc_logging.arn
  log_destination = aws_cloudwatch_log_group.vpc_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc.id
}
