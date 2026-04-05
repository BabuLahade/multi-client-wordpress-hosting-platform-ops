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
    name = "${var.project_name}-ecs-exec-policy"
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