variable "ami_id" {
    description = "AMI ID for the EC2 instance"
    type = string
}
variable "instance_type" {
    description = "EC2 instance type"
    type = string
}
variable "key_name" {
    description = "Name of the SSH key pair"
    type = string
}
variable "project_name" {
    description = "The name of the project, used for tagging resources"
    type = string
}
variable "vpc_id" {
  description = "value"
  type = string
}
variable "subnet_id" {
  description = "value"
  type = string
}
