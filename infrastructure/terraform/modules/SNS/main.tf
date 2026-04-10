resource "aws_sns_topic" "sre_alerts"{
    name = "${var.project_name}-sre-alerts"
}

resource "aws_sns_topic_subscription" "sre_email_sub" {
  topic_arn = aws_sns_topic.sre_alerts.arn
  protocol = "email"
  endpoint = "babulahade@gmail.com"
}