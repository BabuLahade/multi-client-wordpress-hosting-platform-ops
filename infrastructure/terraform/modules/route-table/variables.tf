variable "project_name" {
  description = "name of our project "
  type =string
}

variable "private_app_subnet_ids" {
  description = "value"
  type = list(string)
}
variable "public_subnet_ids" {
  description = "value"
  type = list(string)
}
variable "vpc_id" {
  description = "VPC ID for route table"
  type        = string
}

variable "igw_id" {
  description = "Internet Gateway ID to route traffic to the internet"
  type        = string
}
variable "natgw_ids" {
  description = "List of NAT Gateway IDs to route traffic from private subnets to the internet"
  type        = list(string)
}