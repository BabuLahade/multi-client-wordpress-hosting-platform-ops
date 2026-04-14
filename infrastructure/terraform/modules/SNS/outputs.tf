output "sns_critical_arn" {
    value = aws_sns_topic.critical
}
output "sns_high_arn" {
  value = aws_sns_topic.high.arn 
}