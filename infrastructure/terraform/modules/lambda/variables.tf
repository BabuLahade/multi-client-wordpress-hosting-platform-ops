variable "project_name" {
  type = string
}
variable "tg_arn_suffix" {
  type = map(string)
}
variable "lambda_role_arn" {
    type = string
}
variable "cloudwatch_event_arn" {
    type = string
}