# resource "aws_ecs_cluster" "clients" {
#     name = "${var.project_name}-cluster"
# }
# resource "aws_cloudwatch_log_group" "wordpress_logs" {
#   for_each = toset(var.ecs_clients) # Ensure this matches the variable you use for the other loops
  
#   # Name it uniquely for each client
#   name  = "/ecs/${var.project_name}-${each.key}-wordpress"
#   retention_in_days = 7
# }



# resource "aws_ecs_task_definition" "clients" {
 
#   family = "${var.project_name}-task-family"
#   requires_compatibilities = ["FARGATE"]
#   network_mode = "awsvpc"
#   cpu = "256"
#   memory = "512"
#   execution_role_arn = var.ecs_task_execution_role_arn

#   container_definitions = jsonencode([
#     {
#         name = "wordpress"
#         image = "wordpress:latest"
#         portMappings = [
#         {
#             containerPort = 80
#         }
#         ]
#         essential = true
#         environment = [
#             { name = "WORDPRESS_DB_HOST", value = "${var.db_endpoint}:3306"},
#             { name = "WORDPRESS_DB_USER", value = "admin"},
#             { name = "WORDPRESS_DB_PASSWORD", value = "StrongPassword123!"},
#             { name = "WORDPRESS_DB_NAME", value = "${var.db_name}"}
#         ]
    
#        logConfiguration = {
#          logDriver = "awslogs"
#             options = {
#                 awslogs-group         = "/ecs/wordpress"
#                 awslogs-region        = "eu-north-1"
#                 awslogs-stream-prefix = "ecs"
#   }
# }
#     }
#   ])
# }




# resource "aws_ecs_service" "clients" {
#     for_each = toset(var.ecs_clients)

#     name = "${var.project_name}-${each.key}-service"
#     cluster = aws_ecs_cluster.clients.id
#     task_definition = aws_ecs_task_definition.clients.arn
#     desired_count = 1
#     launch_type = "FARGATE"

#     network_configuration {
#         subnets = var.private_app_subnet_ids
#         security_groups = [var.app_security_group_id]
#         assign_public_ip = false
#      }
    
#     load_balancer {
#       target_group_arn = var.target_group_arn
#       container_name = "wordpress"
#       container_port = 80
#     }
# }

resource "aws_ecs_cluster" "clients" {
  name = "${var.project_name}-cluster"
}

resource "aws_cloudwatch_log_group" "wordpress_logs" {
  for_each          = toset(var.ecs_clients) 
  name              = "/ecs/${var.project_name}-${each.key}-wordpress"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "clients" {
  # FIX 1: Added the missing loop
  for_each                 = toset(var.ecs_clients) 
  
  # FIX 2: Made the family name unique for each client
  family                   = "${var.project_name}-${each.key}-task-family" 
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = "wordpress:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      environment = [
        { name = "WORDPRESS_DB_HOST", value = "${var.db_endpoint}:3306"},
        { name = "WORDPRESS_DB_USER", value = "admin"},
        { name = "WORDPRESS_DB_PASSWORD", value = "StrongPassword123!"},
        { name = "WORDPRESS_DB_NAME", value = "${var.db_name}"}
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          # FIX 3: Dynamically point to the correct log group we built above
          "awslogs-group"         = aws_cloudwatch_log_group.wordpress_logs[each.key].name,
          "awslogs-region"        = "eu-north-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "clients" {
  for_each        = toset(var.ecs_clients)
  name            = "${var.project_name}-${each.key}-service"
  cluster         = aws_ecs_cluster.clients.id
  
  # FIX 4: Dynamically point to the correct task definition for this specific client
  task_definition = aws_ecs_task_definition.clients[each.key].arn 
  
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false # IMPORTANT: Ensure you have a NAT Gateway if this is false!
  }
    
  load_balancer {
    # Note: If you have separate target groups for each client, this might need to be var.target_group_arn[each.key]
    target_group_arn = var.target_group_arn 
    container_name   = "wordpress"
    container_port   = 80
  }
}