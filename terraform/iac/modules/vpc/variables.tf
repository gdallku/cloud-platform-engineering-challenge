variable "aws_region" {}
variable "cidr" {}
variable "environment" {}
variable "log_retention" {}
variable "private_ingress_ports" {
  description = "List of ingress ports to allow"
  type        = list(number)
}
variable "project_name" {}
variable "public_ingress_ports" {
  description = "List of ingress ports to allow"
  type        = list(number)
}
