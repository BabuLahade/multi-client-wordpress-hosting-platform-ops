variable "project_name" {
  description = "value"
  type = string
}

variable "db_endpoint" {
  description = "value"
  type = string
}
variable "db_name" {
  description = "value"
  type = string
}

variable "private_app_subnet_ids" {
  description = "value"
  type = list(string)
}
variable "app_security_group_id" {
  description = "value"
  type = string
}
variable "target_group_arn" {
  description = "value"
  type = map(string)
}
variable "ecs_task_execution_role_arn" {
  description = "value"
  type = string
}

variable "ecs_clients" {
  description = "value"
  type = list(string)
}