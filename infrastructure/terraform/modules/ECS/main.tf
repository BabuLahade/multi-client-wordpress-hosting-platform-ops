# # resource "aws_ecs_cluster" "clients" {
# #     name = "${var.project_name}-cluster"
# # }
# # resource "aws_cloudwatch_log_group" "wordpress_logs" {
# #   for_each = toset(var.ecs_clients) # Ensure this matches the variable you use for the other loops
  
# #   # Name it uniquely for each client
# #   name  = "/ecs/${var.project_name}-${each.key}-wordpress"
# #   retention_in_days = 7
# # }



# # resource "aws_ecs_task_definition" "clients" {
 
# #   family = "${var.project_name}-task-family"
# #   requires_compatibilities = ["FARGATE"]
# #   network_mode = "awsvpc"
# #   cpu = "256"
# #   memory = "512"
# #   execution_role_arn = var.ecs_task_execution_role_arn

# #   container_definitions = jsonencode([
# #     {
# #         name = "wordpress"
# #         image = "wordpress:latest"
# #         portMappings = [
# #         {
# #             containerPort = 80
# #         }
# #         ]
# #         essential = true
# #         environment = [
# #             { name = "WORDPRESS_DB_HOST", value = "${var.db_endpoint}:3306"},
# #             { name = "WORDPRESS_DB_USER", value = "admin"},
# #             { name = "WORDPRESS_DB_PASSWORD", value = "StrongPassword123!"},
# #             { name = "WORDPRESS_DB_NAME", value = "${var.db_name}"}
# #         ]
    
# #        logConfiguration = {
# #          logDriver = "awslogs"
# #             options = {
# #                 awslogs-group         = "/ecs/wordpress"
# #                 awslogs-region        = "eu-north-1"
# #                 awslogs-stream-prefix = "ecs"
# #   }
# # }
# #     }
# #   ])
# # }




# # resource "aws_ecs_service" "clients" {
# #     for_each = toset(var.ecs_clients)

# #     name = "${var.project_name}-${each.key}-service"
# #     cluster = aws_ecs_cluster.clients.id
# #     task_definition = aws_ecs_task_definition.clients.arn
# #     desired_count = 1
# #     launch_type = "FARGATE"

# #     network_configuration {
# #         subnets = var.private_app_subnet_ids
# #         security_groups = [var.app_security_group_id]
# #         assign_public_ip = false
# #      }
    
# #     load_balancer {
# #       target_group_arn = var.target_group_arn
# #       container_name = "wordpress"
# #       container_port = 80
# #     }
# # }

# resource "aws_ecs_cluster" "clients" {
#   name = "${var.project_name}-cluster"
# }

# resource "aws_cloudwatch_log_group" "wordpress_logs" {
#   for_each          = toset(var.ecs_clients) 
#   name              = "/ecs/${var.project_name}-${each.key}-wordpress"
#   retention_in_days = 7
# }

# resource "aws_ecs_task_definition" "clients" {
#   # FIX 1: Added the missing loop
#   for_each                 = toset(var.ecs_clients) 
  
#   # FIX 2: Made the family name unique for each client
#   family                   = "${var.project_name}-${each.key}-task-family" 
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   cpu                      = "256"
#   memory                   = "512"
#   execution_role_arn       = var.ecs_task_execution_role_arn 
#   container_definitions = jsonencode([
#   {
#     name      = "wordpress"
#     image     = "wordpress:latest"
#     essential = true

#     # portMappings = [
#     #   {
#     #     containerPort = 9000
#     #   }
#     # ]

#     environment = [
#       { name = "WORDPRESS_DB_HOST", value = "${var.db_endpoint}:3306" },
#       { name = "WORDPRESS_DB_USER", value = "admin" },
#       { name = "WORDPRESS_DB_PASSWORD", value = "StrongPassword123!" },
#       { name = "WORDPRESS_DB_NAME", value = "wp_${each.key}" }
#     ]

#     logConfiguration = {
#       logDriver = "awslogs"
#       options = {
#         awslogs-group         = aws_cloudwatch_log_group.wordpress_logs[each.key].name
#         awslogs-region        = "eu-north-1"
#         awslogs-stream-prefix = "ecs"
#       }
#     }
#   },

#   {
#     name      = "nginx"
#     image     = "nginx:latest"
#     essential = true

#     portMappings = [
#       {
#         containerPort = 80
#       }
#     ]

#     command = [
#       "sh",
#       "-c",
#       <<EOF
# echo "server {
#     listen 80;

#     location /health {
#         return 200 'healthy';
#     }

#     location / {
#         proxy_pass http://127.0.0.1:80;
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#     }
# }" > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'
# EOF
#     ]

#     logConfiguration = {
#       logDriver = "awslogs"
#       options = {
#         awslogs-group         = aws_cloudwatch_log_group.wordpress_logs[each.key].name
#         awslogs-region        = "eu-north-1"
#         awslogs-stream-prefix = "ecs"
#       }
#     }
#   }
# ])
#   }

# # resource "aws_ecs_task_definition" "clients" {
# #   # FIX 1: Added the missing loop
# #   for_each                 = toset(var.ecs_clients) 
  
# #   # FIX 2: Made the family name unique for each client
# #   family                   = "${var.project_name}-${each.key}-task-family" 
# #   requires_compatibilities = ["FARGATE"]
# #   network_mode             = "awsvpc"
# #   cpu                      = "256"
# #   memory                   = "512"
# #   execution_role_arn       = var.ecs_task_execution_role_arn

# #   container_definitions = jsonencode([
# #     {
# #       name      = "wordpress"
# #       image     = "wordpress:latest"
# #       essential = true
# #       portMappings = [
# #         {
# #           containerPort = 80
# #           hostPort      = 80
# #         }
# #       ]
# #       environment = [
# #         { name = "WORDPRESS_DB_HOST", value = "${var.db_endpoint}:3306"},
# #         { name = "WORDPRESS_DB_USER", value = "admin"},
# #         { name = "WORDPRESS_DB_PASSWORD", value = "StrongPassword123!"},
# #         { name = "WORDPRESS_DB_NAME", value = "wp_${each.key}"}
# #       ]
# #       logConfiguration = {
# #         logDriver = "awslogs"
# #         options = {
# #           # FIX 3: Dynamically point to the correct log group we built above
# #           "awslogs-group"         = aws_cloudwatch_log_group.wordpress_logs[each.key].name,
# #           "awslogs-region"        = "eu-north-1",
# #           "awslogs-stream-prefix" = "ecs"
# #         }
# #       }
# #     }
    
# #   ])
# # }

# resource "aws_ecs_service" "clients" {
#   for_each        = toset(var.ecs_clients)
#   name            = "${var.project_name}-${each.key}-service"
#   cluster         = aws_ecs_cluster.clients.id
  
#   # FIX 4: Dynamically point to the correct task definition for this specific client
#   task_definition = aws_ecs_task_definition.clients[each.key].arn 
  
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = var.private_app_subnet_ids
#     security_groups  = [var.app_security_group_id]
#     assign_public_ip = false # IMPORTANT: Ensure you have a NAT Gateway if this is false!
#   }
    
#   load_balancer {
#     # Note: If you have separate target groups for each client, this might need to be var.target_group_arn[each.key]
#     target_group_arn = var.target_group_arn[each.key]
#     container_name   = "nginx"
#     container_port   = 80
#   }
# }
# # resource "aws_ecs_task_definition" "clients" {
# #   # FIX 1: Added the missing loop
# #   for_each                 = toset(var.ecs_clients) 
  
# #   # FIX 2: Made the family name unique for each client
# #   family                   = "${var.project_name}-${each.key}-task-family" 
# #   requires_compatibilities = ["FARGATE"]
# #   network_mode             = "awsvpc"
# #   cpu                      = "256"
# #   memory                   = "512"
# #   execution_role_arn       = var.ecs_task_execution_role_arn 
# #   container_definitions = jsonencode([
# #   {
# #     name      = "wordpress"
# #     image     = "wordpress:latest"
# #     essential = true

# #     portMappings = [
# #       {
# #         containerPort = 80
# #       }
# #     ]

# #     environment = [
# #       { name = "WORDPRESS_DB_HOST", value = var.db_endpoint },
# #       { name = "WORDPRESS_DB_USER", value = "admin" },
# #       { name = "WORDPRESS_DB_PASSWORD", value = "StrongPassword123!" },
# #       { name = "WORDPRESS_DB_NAME", value = "wp_${each.key}" }
# #     ]

# #     logConfiguration = {
# #       logDriver = "awslogs"
# #       options = {
# #         awslogs-group         = aws_cloudwatch_log_group.wordpress_logs[each.key].name
# #         awslogs-region        = "eu-north-1"
# #         awslogs-stream-prefix = "ecs"
# #       }
# #     }
# #   },

# #   {
# #     name      = "nginx"
# #     image     = "nginx:latest"
# #     essential = true

# #     portMappings = [
# #       {
# #         containerPort = 80
# #       }
# #     ]

# #     command = [
# #       "sh",
# #       "-c",
# #       <<EOF
# # echo "server {
# #     listen 80;

# #     location /health {
# #         return 200 'healthy';
# #     }

# #     location / {
# #         proxy_pass http://127.0.0.1:80;
# #         proxy_set_header Host \$host;
# #         proxy_set_header X-Real-IP \$remote_addr;
# #         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
# #         proxy_set_header X-Forwarded-Proto \$scheme;
# #     }
# # }" > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'
# # EOF
# #     ]

# #     logConfiguration = {
# #       logDriver = "awslogs"
# #       options = {
# #         awslogs-group         = aws_cloudwatch_log_group.wordpress_logs[each.key].name
# #         awslogs-region        = "eu-north-1"
# #         awslogs-stream-prefix = "ecs"
# #       }
# #     }
# #   }
# # ])
# #   }


resource "aws_ecs_cluster" "clients" {
  name = "${var.project_name}-cluster"
  setting {
    name = "containerInsights"
    value = "enabled"
  }
}

# resource "aws_cloudwatch_log_group" "wordpress_logs" {
#   for_each          = toset(var.ecs_clients) 
#   name              = "/ecs/${var.project_name}-${each.key}-wordpress"
#   retention_in_days = 7
# }
resource "aws_efs_access_point" "wordpress_ap" {
  for_each       = toset(var.ecs_clients)
  file_system_id = var.efs_file_system_id

  posix_user {
    gid = 33
    uid = 33
  }

  root_directory {
    path = "/wp-${each.key}"
    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0755" 
    }
  }
}

# resource "aws_ecs_task_definition" "clients" {
#   for_each                 = toset(var.ecs_clients) 
#   family                   = "${var.project_name}-${each.key}-task-family" 
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   cpu                      = "256"
#   memory                   = "512"
#   execution_role_arn       = var.ecs_task_execution_role_arn 

#   # CREATE THE SHARED VOLUME FOR FPM AND NGINX
#   volume {
#     name = "wordpress-files"
#     efs_volume_configuration {
#       file_system_id = var.efs_file_system_id
#       transit_encryption = "ENABLED"
#     }
#   }

# #   
# container_definitions = jsonencode([

#   #  i want to add database per client auto matically 
#   {
#     name = "db-init"
#     image = "mysql:8.0"
#     essential = false

#     environment = [
#       { name = "MYSQL_PWD", value = "StrongPassword123!" },
    
#     ]
#     command =[
#       "sh" , "-c" ,
#       "mysql -h ${var.db_endpoint} -u admin -e 'CREATE DATABASE IF NOT EXISTS wp_${each.key};'"
#     ]   
#     logConfiguration = {
#       logDriver ="awslogs"
#       options = {
#         awslogs-group = aws_cloudwatch_log_group.wordpress_logs[each.key].name
#         awslogs-region = "eu-north-1"
#         awslogs-stream-prefix ="ecs-db-init"
#       }
#     }

#   },
#   {
#     name      = "wordpress"
#     image     = "wordpress:fpm"
#     essential = true

#     depends_on =[
#       {
#         container_name = "db-init"
#         condition = "SUCCESS"
#       }
#     ]
#     mountPoints = [
#       {
#         sourceVolume  = "wordpress-files"
#         containerPath = "/var/www/html/wp-content"
#       }
#     ]
#     # NO portMappings (important)

#     environment = [
#       { name = "WORDPRESS_DB_HOST", value = "${var.db_endpoint}" },
#       { name = "WORDPRESS_DB_USER", value = "admin" },
#       { name = "WORDPRESS_DB_PASSWORD", value = "StrongPassword123!" },
#       { name = "WORDPRESS_DB_NAME", value = "wordpress" }
#     ]

#     logConfiguration = {
#       logDriver = "awslogs"
#       options = {
#         awslogs-group         = aws_cloudwatch_log_group.wordpress_logs[each.key].name
#         awslogs-region        = "eu-north-1"
#         awslogs-stream-prefix = "ecs"
#       }
#     }
#   },

#     {
#     name      = "nginx"
#     image     = "nginx:latest"
#     essential = true

#     depends_on =[
#       {
#         container_name = "wordpress"
#         condition = "START"
#       }
#     ]
#     portMappings = [
#       {
#         containerPort = 80
#       }
#     ]
    
#     mountPoints = [
#       {
#         sourceVolume  = "wordpress-files"
#         containerPath = "/var/www/html/wp-content"
#       }
#     ]
    
#     #  added fastcgi_pass to port 9000 so it connect to  wordpress:fpm container.
#     command = [
#       "/bin/sh", "-c",
#       "echo 'server { listen 80; root /var/www/html; index index.php; location /health { access_log off; return 200 \"healthy\"; } location / { try_files $uri $uri/ /index.php?$args; } location ~ \\.php$ { fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; include fastcgi_params; } }' > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
#     ]

#     logConfiguration = {
#       logDriver = "awslogs"
#       options = {
#         awslogs-group         = aws_cloudwatch_log_group.wordpress_logs[each.key].name
#         awslogs-region        = "eu-north-1"
#         awslogs-stream-prefix = "ecs-nginx" # Separated the prefix so Nginx and WP logs don't mix!
#       }
#     }
#   }
# #   {
# #     name      = "nginx"
# #     image     = "nginx:latest"
# #     essential = true

# #     portMappings = [
# #       {
# #         containerPort = 80
# #       }
# #     ]
# #     mountPoints =[
# #       {
# #         sourceVolume = "wordpress-files"
# #         containerPath = "/var/www/html"
# #       }
# #     ]
# #     command = [
# #       "sh",
# #       "-c",
# #       <<EOF
# # echo "server {
# #     listen 80 default_server;
# #     server_name _;

# #     location /health {
# #         access_log off;
# #         return 200 'healthy';
# #     }

# #     location / {
# #         proxy_pass http://127.0.0.1:80;
# #         proxy_http_version 1.1;
# #         proxy_set_header Host \$host;
# #         proxy_set_header X-Real-IP \$remote_addr;
# #         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
# #         proxy_set_header Connection \"\";
# #     }
# # }" > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'
# # EOF
# #     ]

# #     logConfiguration = {
# #       logDriver = "awslogs"
# #       options = {
# #         awslogs-group         = aws_cloudwatch_log_group.wordpress_logs[each.key].name
# #         awslogs-region        = "eu-north-1"
# #         awslogs-stream-prefix = "ecs"
# #       }
# #     }
# #   }
# ])
# }

resource "aws_ecs_task_definition" "clients" {
  for_each                 = toset(var.ecs_clients) 
  family                   = "${var.project_name}-${each.key}-task-family" 
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn 
  task_role_arn = var.ecs_task_role_arn
  # FIXED: Mount the Access Point, not the root drive
  volume {
    name = "wordpress-files"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.wordpress_ap[each.key].id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "db-init"
      image     = "mysql:8.0"
      essential = false
      secrets = [
        { name = "MYSQL_PWD", valueFrom = var.db_secret_arn },
      ]
      command = [
        "sh" , "-c" ,
        "mysql -h ${var.db_endpoint} -u admin -e 'CREATE DATABASE IF NOT EXISTS wp_${each.key};'"
      ]   
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.cloudwatch_log_group_name[each.key]
          awslogs-region        = "eu-north-1"
          awslogs-stream-prefix = "ecs-db-init"
        }
      }
    },
    {
      name      = "wordpress"
      image     = var.custom_wordpress_image
      essential = true
      depends_on = [
        {
          container_name = "db-init"
          condition      = "SUCCESS"
        }
      ]
      
      # FIXED: Mount the entire HTML folder
      mountPoints = [
        {
          sourceVolume  = "wordpress-files"
          containerPath = "/var/www/html" 
        }
      ]
      
      environment = [
        { name = "WORDPRESS_DB_HOST", value = "${var.db_endpoint}" },
        { name = "WORDPRESS_DB_USER", value = "admin" },
         
        { name = "WORDPRESS_DB_NAME", value = "wp_${each.key}" },

        # valkey
        { name = "VALKEY_HOST", value = var.valkey_endpoint },
        { name = "REDIS_HOST", value = var.valkey_endpoint },
        { name = "REDIS_PORT" , value = "6379" },
        { name = "CLIENT_ID"  , value = each.key }
      ]
      secrets = [
        { name = "WORDPRESS_DB_PASSWORD", valueFrom = var.db_secret_arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.cloudwatch_log_group_name[each.key]
          awslogs-region        = "eu-north-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "nginx"
      image     = "nginx:latest"
      essential = true
      depends_on = [
        {
          container_name = "wordpress"
          condition      = "START"
        }
      ]
      portMappings = [
        {
          containerPort = 80
        }
      ]
      
      mountPoints = [
        {
          sourceVolume  = "wordpress-files"
          containerPath = "/var/www/html"
        }
      ]
      
      # THE FIX: Added 'fastcgi_param HTTPS on;' inside the location ~ \.php$ block!
      command = [
        "/bin/sh", "-c",
        # "echo 'server { listen 80; root /var/www/html; index index.php; location /health { access_log off; return 200 \"healthy\"; } location / { try_files $uri $uri/ /index.php?$args; } location ~ \\.php$ { fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; include fastcgi_params; fastcgi_param HTTPS on; } }' > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
        "echo 'server { listen 80; root /var/www/html; index index.php; location / { try_files $uri $uri/ /index.php?$args; } location ~ \\.php$ { fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; include fastcgi_params; fastcgi_param HTTPS on; } }' > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.cloudwatch_log_group_name[each.key]
          awslogs-region        = "eu-north-1"
          awslogs-stream-prefix = "ecs-nginx" 
        }
      }
    }
  ])
}

resource "aws_ecs_service" "clients" {
  for_each        = toset(var.ecs_clients)
  name            = "${var.project_name}-${each.key}-service"
  cluster         = aws_ecs_cluster.clients.id
  task_definition = aws_ecs_task_definition.clients[each.key].arn 
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true
  health_check_grace_period_seconds = 60
  network_configuration {
    subnets          = values(var.private_app_subnet_ids)
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false
  }
    
  load_balancer {
    target_group_arn = var.target_group_arn[each.key]
    container_name   = "nginx"
    container_port   = 80
  }
  deployment_circuit_breaker {
    enable = true 
    rollback = true
  }
  alarms {
    enable = true 
    rollback = true
    alarm_names = [
    
      var.ecs_memory_high[each.key],
      var.alb_5xx_alarm[each.key]
    ]
  }
  lifecycle {
    ignore_changes = [desired_count]
  }
}

## autoscaling target
resource "aws_appautoscaling_target" "ecs" {
  for_each = toset(var.ecs_clients)

  max_capacity = 5
  min_capacity = 2

  resource_id = "service/${aws_ecs_cluster.clients.name}/${aws_ecs_service.clients[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"


}

##### auto scaling policy

resource "aws_appautoscaling_policy" "ecs_policy" {
  for_each = toset(var.ecs_clients)

  name = "${each.key}-cpu-scaling-policy"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  service_namespace = aws_appautoscaling_target.ecs[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"

    }
     target_value = 60.0
     scale_out_cooldown = 60
     scale_in_cooldown = 60 
  }
}