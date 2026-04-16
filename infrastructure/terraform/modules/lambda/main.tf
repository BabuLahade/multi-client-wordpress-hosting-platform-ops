data "archive_file" "error_budget_zip" {
  type        = "zip"
  source_file = "${path.module}/error_budget.py"
  output_path = "${path.module}/error_budget.zip"
}

# resource "aws_lambda_function" "error_budget_calculator" {
#   filename      = "lambda_function_payload.zip" # Your zipped python file
#   function_name = "${var.project_name}-error-budget-calc"
#   role          = aws_iam_role.lambda_exec.arn
#   handler       = "error_budget.handler"
#   runtime       = "python3.12"
#   timeout       = 30 # Give it 30 seconds since it makes multiple API calls

#   environment {
#     variables = {
#       SLO_TARGET    = "0.995"
#       # MAGIC TRICK: Pass the entire target group map to Python automatically!
#       TARGET_GROUPS = jsonencode(var.tg_arn_suffix) 
#     }
#   }
# }

# resource "aws_lambda_function" "error_budget" {
#   function_name = "wordpress-error-budget-tracker"
#   runtime       = "python3.12"
#   handler       = "error_budget.handler"
#   role          = var.lambda_role_arn
#   filename      = "lambda/error_budget.zip"
#   timeout       = 60
# }

# 5. The Lambda Function itself
resource "aws_lambda_function" "error_budget" {
  function_name = "${var.project_name}-error-budget-tracker"
  runtime       = "python3.12"
  handler       = "error_budget.handler"
  role          = var.lambda_role_arn
  
  # Point to the auto-zipper we created above
  filename         = data.archive_file.error_budget_zip.output_path
  source_code_hash = data.archive_file.error_budget_zip.output_base64sha256
  
  timeout       = 60

  environment {
    variables = {
      SLO_TARGET    = "0.995"
      # This passes your clients directly to Python!
      TARGET_GROUPS = jsonencode(var.tg_arn_suffix) 
    }
  }
}


resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.error_budget.function_name
  principal     = "events.amazonaws.com"
  source_arn    = var.cloudwatch_event_arn
}