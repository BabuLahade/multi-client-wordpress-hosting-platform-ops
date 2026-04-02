resource "aws_ecs_cluster" "clients" {
    name = "${var.project_name}-cluster"
}

resource "aws_ecs_task_definition" "clients" {
 
  family = "${var.project_name}-task-family"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "256"
  memory = "512"
  execution_role_arn = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
        name = "wordpress"
        image = "wordpress:latest"

        essential = true
        environment = [
            { name = "WORDPRESS_DB_HOST", value = "${var.db_endpoint}:3306"},
            { name = "WORDPRESS_DB_USER", value = "admin"},
            { name = "WORDPRESS_DB_PASSWORD", value = "StrongPassword123!"},
            { name = "WORDPRESS_DB_NAME", value = "${var.db_name}"}
        ]
    },
    {
        name = "nginx"
        image = "nginx:latest"

        essential = true
        portMappings = [
            {
                containerPort = 80
                hostPort = 80

            }
        ]
    }
  ])

}

resource "aws_ecs_service" "clients" {
    name = "${var.project_name}-service"
    cluster = aws_ecs_cluster.clients.id
    task_definition = aws_ecs_task_definition.clients.arn
    desired_count = 1
    launch_type = "FARGATE"

    network_configuration {
        subnets = var.private_app_subnet_ids
        security_groups = [var.app_security_group_id]
        assign_public_ip = false
     }
    
    load_balancer {
      target_group_arn = var.target_group_arn
      container_name = "nginx"
      container_port = 80
    }
}