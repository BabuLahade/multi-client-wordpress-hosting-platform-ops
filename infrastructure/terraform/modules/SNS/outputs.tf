output "sns_critical_arn" {
    value = aws_sns_topic.critical.arn
}
output "sns_high_arn" {
  value = aws_sns_topic.high.arn 
}