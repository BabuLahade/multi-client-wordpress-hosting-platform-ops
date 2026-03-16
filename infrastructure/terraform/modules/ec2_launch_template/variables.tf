variable "project_name" {
  description = "Name of the project used for tagging resources"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type for EC2"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair for EC2 instances"
  type        = string
}
# variable "security_group_id" {
#   description = "Security group ID to associate with EC2 instances"
#   type        = string
# }
# variable "public_subnet_ids" {
#   description = "List of public subnet IDs to associate with EC2 instances"
#   type        = list(string)
# }
variable "app_security_group_id" {
  description = "Security group ID for application instances"
  type        = string
}
variable "iam_instance_profile_name" {
  description = "value"
  type = string 
}