resource "aws_iam_role" "ec2_role" {
    name = "${var.project_name}-ec2-role"
    assume_role_policy = jsonencode ({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
            Action = "sts:AssumeRole"   
        }]
    })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
    role = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


##ssm
### ssm ec2
### ssm EC2 profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
    name = "${var.project_name}-ec2-instance-profile"
    role = aws_iam_role.ec2_role.name
}

# resource "aws_iam_role" "ec2_ssm_role" {
#     name = "${var.project_name}-ec2-ssm-role"
#     assume_role_policy = jsonencode({
#         Version = "2012-10-17"
#         Statement = [{
#             Action = "sts:AssumeRole"
#             Effect = "Allow"
#             Principal = {
#                 Service = "ec2.amazonaws.com"
#             }
#         }]
#     })
# }
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy_attachment" {
    role = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# resource "aws_iam_instance_profile" "ec2_ssm_instance_profile" {
#     name = "${var.project_name}-ec2-ssm-instance-profile"
#     role = aws_iam_role.ec2_ssm_role.name
# }

resource "aws_iam_role" "ecs_task_execution_role" {
    name = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
            Service = "ecs-tasks.amazonaws.com"
        }
    }] 
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
    role = aws_iam_role.ecs_task_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
    name = "${var.project_name}-ecs-task-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal ={
                Service = "ecs-tasks.amazonaws.com"
            }
        }]
    })
}
resource "aws_iam_policy" "ecs_exec_policy" {
    name = "${var.project_name}-ecs-exec-policy-v2"
    description = "Policy to allow ECS Exec access"
    policy = jsonencode ({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ]
            Resource = "*"
        }]
    })
}
resource "aws_iam_role_policy" "s3_offload_policy" {
    name ="${var.project_name}-s3-offload-policy"
    role = aws_iam_role.ecs_task_role.id
    policy =jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:DeleteObject"

            ]
            Resource = [
                var.media_bucket_arn,
                "${var.media_bucket_arn}/*"  ,
                # ADDED: The legacy format the WordPress plugin is asking for!
                "arn:aws:s3:::${var.project_name}-media-*",  
                "arn:aws:s3:::${var.project_name}-media-*/*"
            ]
        }]
    })
}
resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment" {
    role = aws_iam_role.ecs_task_role.name
    policy_arn = aws_iam_policy.ecs_exec_policy.arn
}

resource "aws_iam_role_policy" "ecs_secrets_policy" {
    name = "${var.project_name}-ecs-secrets-policy"
    role = aws_iam_role.ecs_task_execution_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement =[{
            Effect = "Allow"
            Action = [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ]
            Resource = "*"
        }]
    })
}

#### grafana 
# resource "aws_iam_user" "grafana_service" {
#     name = "${var.project_name}-grafana"
#     path = "/system/"
# }

# resource "aws_iam_policy" "grafana_cloudwatch_policy" {
#     name = "${var.project_name}-grafana-cloudwatch-policy"
#     description = "Allows Grafana Cloud to read CloudWatch metrics and logs"

#     policy = jsonencode({
#         Version = "2012-10-17"
#         Statement = [
#             {
#                 Effect = "Allow"
#                 Action = [
#                     "cloudwatch:GetMetricData",
#                     "cloudwatch:ListMetrics",
#                     "cloudwatch:DescribeAlarms",
#                     "logs:StartQuerry",
#                     "logs:GetQuerryResults",
#                     "logs:DescribeLogGroups"
                    
#                 ]
#                 Resource = "*"
#             }
#         ]
#     })
# }
# resource "aws_iam_user_policy_attachment" "grafana_attach" {
#     user = aws_iam_user.grafana_service.name
#     policy_arn = aws_iam_user.grafana_cloudwatch_policy.arn
   
# }

resource "aws_iam_role" "lambda_error_budget" {
  name = "${var.project_name}-error-budget-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# 3. Allow Lambda to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_error_budget.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 4. Allow Lambda to read/write your custom metrics
resource "aws_iam_role_policy" "lambda_metrics_access" {
  name = "${var.project_name}-error-budget-metrics-policy"
  role = aws_iam_role.lambda_error_budget.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:PutMetricData"
      ]
      Resource = "*" # CloudWatch metrics don't use specific ARNs
    }]
  })
}
resource "aws_iam_role" "auto_heal_role" {
  name = "${var.project_name}-auto-heal-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.auto_heal_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
resource "aws_iam_role_policy" "lambda_secrets_access" {
  name = "${var.project_name}-lambda-secrets-policy"
  role = aws_iam_role.auto_heal_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.db_secret_arn # Replace with your actual Secret resource name
      }
    ]
  })
}

###############
resource "aws_iam_role" "slack_lambda_role" {
  name = "wordpress-slack-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "slack_lambda_basic" {
  role       = aws_iam_role.slack_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}