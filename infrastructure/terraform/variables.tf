# variable "project_name" {
#   description = "Name of the project used for tagging resources"
#   type        = string
# }

# variable "vpc_cidr" {
#   description = "CIDR block for the VPC"
#   type        = string
# }

# variable "availability_zones" {
#   description = "List of availability zones"
#   type        = list(string)
# }

# variable "public_subnet_cidrs" {
#   description = "CIDR blocks for public subnets"
#   type        = list(string)
# }

# variable "private_app_subnet_cidrs" {
#   description = "CIDR blocks for private application subnets"
#   type        = list(string)
# }

# variable "private_db_subnet_cidrs" {
#   description = "CIDR blocks for private database subnets"
#   type        = list(string)
# }

# variable "ami_id" {
#   description = "AMI ID for EC2 instances"
#   type        = string
# }

# variable "instance_type" {
#   description = "Instance type for EC2"
#   type        = string
# }

variable "project_name" {
  description = "Name of the project used for tagging resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}