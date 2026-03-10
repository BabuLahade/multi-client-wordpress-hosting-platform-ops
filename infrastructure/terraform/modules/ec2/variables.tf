variable "ami_id" {
    description = "AMI ID for EC2 instances"
    type = string
  
}
variable "instance_type" {
    description = "EC2 instance type"
    type = string
}
variable "private_app_subnet_ids" {
    description = "List of private subnet IDs for app instances"
    type = list(string)
}
variable "security_group_id" {
    description = "Security group ID for app instances"
    type = string
}
variable "project_name" {
    description = "The name of the project, used for tagging resources"
    type = string
}