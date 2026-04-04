variable "project_name" {
    description = "project name"
    type = string
}
variable "private_app_subnet_ids" {
    description = "List of private app subnet IDs for EFS mount targets"
    type = map(string)
}
variable "efs_security_group_id" {
    description = "Security group ID for EFS mount targets"
    type = string
}