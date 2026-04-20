output "error_budget_arn" {
    value = aws_lambda_function.error_budget.arn
}
output "lambda_auto_heal_arn" {
    value = aws_lambda_function.auto_heal_lambda.arn
}