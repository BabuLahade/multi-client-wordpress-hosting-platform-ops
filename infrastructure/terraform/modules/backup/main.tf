resource "aws_backup_vault" "main_vault" {
  name = "${var.project_name}-backup-vault"
}

resource "aws_backup_plan" "daily_plan" {
  name = "${var.project_name}-daily-efs-backup"

  rule {
    rule_name         = "daily-retention-14-days"
    target_vault_name = aws_backup_vault.main_vault.name
    schedule          = "cron(0 5 ? * * *)" 

    lifecycle {
      delete_after = 14
    }
  }
}

resource "aws_backup_selection" "efs_backup_selection" {
  iam_role_arn = aws_iam_role.aws_backup_role.arn
  name         = "${var.project_name}-efs-selection"
  plan_id      = aws_backup_plan.daily_plan.id

  resources = [var.efs_arn]
}
resource "aws_backup_selection" "efs_backup_selection" {
  iam_role_arn = aws_iam_role.aws_backup_role.arn
  name         = "${var.project_name}-efs-selection"
  plan_id      = aws_backup_plan.daily_plan.id

  resources = [var.efs_arn]
}
resource "aws_iam_role" "aws_backup_role" {
  name = "${var.project_name}-aws-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.aws_backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}