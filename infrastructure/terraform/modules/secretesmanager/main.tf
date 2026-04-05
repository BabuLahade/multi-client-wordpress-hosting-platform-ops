resource "random_password" "db_password" {
  length = 16
  special  = false
}
## creating secret vault 
resource "aws_secretsmanager_secret" "db_secret" {
    name = "${var.project_name}-db-password"
    recovery_window_in_days = 0


}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
    secret_id = aws_secretsmanager_secret.db_secret.id
    secret_string = random_password.db_password.result
}