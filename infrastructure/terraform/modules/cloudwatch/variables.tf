variable "project_name" {
    description = "value"
    type = string
}

variable "ecs_clients" {
    description = "value"
    type= list(string)
}
variable "cluster_name" {
  description = "value"
  type = string
}
variable "sns_critical_arn" {
  type = string
}
variable "sns_high_arn"{
  type = string
}
variable "db_instance_id" {
    type = string
}
variable "alb_arn" {
    type = string 
}
variable "cache_id" {
  type = string
}
variable "alb_arn_suffix" {
  type = string
}
# variable "service_name" {
#   type = map(string)
# }
variable "tg_arn_suffix" {
  type = map(string)
}
variable "error_budget_arn" {
  type = string
}
variable "efs_file_system_id" {
  type = string
}
variable "certificate_arn" {
  type = string
}
variable "lambda_auto_heal_arn" {
  type =string
}