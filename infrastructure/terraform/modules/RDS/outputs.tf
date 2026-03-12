output "db_instance_endpoint" {
  value = aws_db_instance.wordpress_db
}

output "db_instance_id" {
  value = aws_db_instance.wordpress_db.id
}

output "db_instance_port" {
  value = aws_db_instance.wordpress_db.port
}

output "db_instance_arn" {
  value = aws_db_instance.wordpress_db.arn
}

output "db_instance_status" {
  value = aws_db_instance.wordpress_db.status
}