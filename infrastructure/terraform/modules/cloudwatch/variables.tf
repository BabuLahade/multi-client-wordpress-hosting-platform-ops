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
variable "sns_arn" {
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