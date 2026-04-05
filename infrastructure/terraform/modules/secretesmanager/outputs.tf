output "secret_db_password" {
    value = random_password.db_password.result
}
output "db_secret_arn" {
    value = aws_secretsmanager_secret.db_secret.arn
}