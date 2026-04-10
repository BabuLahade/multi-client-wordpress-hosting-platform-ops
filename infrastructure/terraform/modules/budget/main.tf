resource "aws_budgets_budget" "finops_budget" {
  name = "monthly-15-dollar-limit"
  budget_type = "COST"
  limit_amount = "15"
  limit_unit = "USD"
  time_unit = "MONTHLY"

  ### alert if we hit all $15
  notification {
    comparison_operator = "GREATER_THAN"
    threshold = 100
    threshold_type = "PERCENTAGE"
    notification_type = "ACTUAL"
    subscriber_email_addresses = ["babulahade@gmail.com"]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["babulahade@gmail.com"] 
  }

}