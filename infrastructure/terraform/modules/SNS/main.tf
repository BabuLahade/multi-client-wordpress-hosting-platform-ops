resource "aws_sns_topic" "critical"{
    name = "${var.project_name}-critical-alert"
}
resource "aws_sns_topic" "high" {
  name = "${var.project_name}-high-alert"
}
resource "aws_sns_topic" "warning" {
  name = "${var.project_name}-warning-alert"
}


resource "aws_sns_topic_subscription" "email_critical" {
  topic_arn = aws_sns_topic.critical.arn
  protocol = "email"
  endpoint = "babulahade@gmail.com"
}
resource "aws_sns_topic_subscription" "email_high" {
  topic_arn = aws_sns_topic.high.arn
  protocol = "email"
  endpoint = "babulahade@gmail.com"
}


resource "aws_sns_topic_subscription" "slack_critical_sub" {
  topic_arn = aws_sns_topic.critical.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notify_lambda.arn
}