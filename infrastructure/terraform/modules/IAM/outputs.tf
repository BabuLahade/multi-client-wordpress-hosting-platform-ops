output "iam_instance_profile_name" {
    value = aws_iam_instance_profile.ec2_instance_profile.name
}
output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  value =aws_iam_role.ecs_task_role.arn
}
# output "grafana_access_key_id" {
#   value       = aws_iam_access_key.grafana_keys.id
#   description = "Copy this into Grafana CloudWatch config"
# }

# output "grafana_secret_access_key" {
#   value       = aws_iam_access_key.grafana_keys.secret
#   description = "Copy this into Grafana CloudWatch config"
#   sensitive   = true 
# }

output "lambda_role_arn" {
  value = aws_iam_role.lambda_error_budget.arn
}
output "lambda_iam_auto_heal_arn" {
  value = aws_iam_role.auto_heal_role.arn
}