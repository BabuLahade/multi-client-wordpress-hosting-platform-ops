output "efs_file_system_id" {
    value = aws_efs_file_system.wordpress.id
}
output "efs_arn" {
    value = aws_efs_file_system.wordpress.arn
}