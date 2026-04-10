output "sns_arn" {
    value = aws_sns_topic.sre_alerts.arn
}