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
variable "lambda_iam_auto_heal_arn"{
  type = string
}
variable "db_user" {
  type = string
}
variable "private_app_subnet_ids" {
  type = map(string)
}
variable "app_security_group_id" {
  type = string
}
variable "db_instance_address" {
  type = string
}

variable "primary_endpoint_address" {
  type = string
}
variable "cloudwatch_auto_heal_arn" {
  type = string
}
variable "db_secret_arn" {
  type = string
}
variable "slack_webhook_url" {
  description = "The Slack Incoming Webhook URL"
  type        = string
}

variable "grafana_url" {
  description = "The base URL for your Grafana dashboard"
  type        = string
}
variable "slack_lambda_role_arn" {
  type = string
}