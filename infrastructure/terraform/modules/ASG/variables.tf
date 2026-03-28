variable "project_name" {
    description = "The name of the project, used for tagging resources"
    type = string
}
variable "vpc_id" {
    description = "VPC ID for security group"
    type        = string
}
variable "private_app_subnet_ids" {
    description = "List of private subnet IDs for application instances"
    type        = list(string)
}
variable "target_group_arn" {
    description = "value"
    type = string 
}
variable "launch_template_id_1" {
    description = "launch template id"
    type = string
}
variable "launch_template_id_2" {
    description = "launch template id"
    type = string
}