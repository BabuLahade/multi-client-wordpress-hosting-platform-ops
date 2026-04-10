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