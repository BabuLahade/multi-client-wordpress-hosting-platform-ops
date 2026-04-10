output "cloudwatch_log_group_name" {
    value={
        for k ,v in aws_cloudwatch_log_group.wordpress_logs : k=>v.name
    }
}