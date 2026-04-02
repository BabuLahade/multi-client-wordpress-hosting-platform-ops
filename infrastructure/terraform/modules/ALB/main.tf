# resource "aws_application_load_balancer" "alb"{
#     name = "${var.project_name}-alb"
#     load_balancer_type = "application"
#     internal = false 
#     security_groups = [aws_security_group.alb_sg.id ]
#     subnets = var.public_subntes_ids
#     tags = {
#         Name = "${var.project_name}-alb"
#     }
# }
# # resource "aws_appliction_load_balancer_listener" "alb_listener" {
# #     load_balancer_arn = aws_application_lad_balancer.alb.arn
# #     port = 80
# #     protocol = "HTTP"
# #     vpc_id = aws_vpc.main.id 
    
# #     # default_action {
# #     #     type = "fixed-response"
# #     #     fixed_response {
# #     #         content_type = "text/plain"
# #     #         message_body = "Service Unavailable"
# #     #         status_code = 503
# #     #     }
# #     # }
# #     default_action {
# #         type = "forward"
# #         target_group_arn = aws_alb_target_group.alb_tg.arn
# #     }
# # }

#  resource "aws_lb_target_group" "tg" {
#     name ="${var.project_name}-tg"
#     port = 80
#     protocol = "HTTP"
#     vpc_id = aws_vpc.main.id
#     health_check {
#         path="/"
#         protocol = "HTTP"
#         interval = 30
#         timeout = 5
#         healthy_threshold = 5
#         unhealthy_threshold = 2

#     }
# }
# resource "aws_lb_listener" "listener" {
#     load_balancer_arn = aws_lb.alb.arn
#     port = 80
#     protocol = "HTTP"
#     default_action {
#         type = "forward"
#         target_group_arn = aws_lb_target_group.tg.arn
#     }
  
# }


resource "aws_lb" "alb" {
    name = "${var.project_name}-alb"
    load_balancer_type = "application"
    internal = false
    subnets = var.public_subnet_ids
    security_groups = [var.alb_security_group_id]
    tags = {
        Name = "${var.project_name}-alb"
    }
}

# resource "aws_lb_target_group" "alb_tg_1" {
#     name = "${var.project_name}-alb-tg-1"
#     port = 80
#     protocol = "HTTP"

#     vpc_id = var.vpc_id
#     health_check {
#         path = "/"
#         protocol = "HTTP"
#         interval = 30
#         timeout = 5
#         matcher = "200-399" 
#         healthy_threshold = 5
#         unhealthy_threshold = 2

#     }
# }

# resource "aws_lb_target_group" "alb_tg_2" {
#     name = "${var.project_name}-alb-tg-2"
#     port =80
#     protocol = "HTTP"
#     vpc_id = var.vpc_id
#     health_check {
#       path = "/"
#       protocol ="HTTP"
#       interval = 30
#       timeout = 5
#       matcher = "200-399"
#       healthy_threshold = 5
#       unhealthy_threshold = 2
#     }
# }

resource "aws_lb_target_group" "clients" {
    for_each = toset(var.clients)
    name = "tg-${each.key}"
    port =80
    

    protocol = "HTTP"
    vpc_id = var.vpc_id
    health_check {
      path = "/"
      protocol = "HTTP"
      interval = 30
      timeout = 5
      matcher ="200-390"
      healthy_threshold = 5
      unhealthy_threshold = 2
    }
}

resource "aws_lb_listener" "alb_listener" {
    # for_each = toset(var.clients)
    load_balancer_arn = aws_lb.alb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
        status_code = "200"
        content_type = "text/plain"
        message_body = "ok"
      }
    #   target_group_arns = aws_lb_target_group.clients.arn
    }
}

# resource "aws_lb_listener" "alb_listener_1"{
#     load_balancer_arn =aws_lb.alb.arn
#     port = 80       you have to change port bcz posrt is already in use 
#     protocol = "HTTP"

#     default_action {
#       type ="forward"
#       target_group_arn = aws_lb_target_group.alb_tg_2.arn
#     }
# }

# resource "aws_lb_listener_rule" "client1" {
#   listener_arn = aws_lb_listener.alb_listener.arn
#   priority     = 10

#   condition {
#     host_header {
#       values = ["client1.local"]
#     }
#   }

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.alb_tg_1.arn
#   }
# }

# resource "aws_lb_listener_rule" "client2" {
#   listener_arn = aws_lb_listener.alb_listener.arn
#   priority     = 20

#   condition {
#     host_header {
#       values = ["client2.local"]
#     }
#   }

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.alb_tg_2.arn
#   }
# }

resource "aws_lb_listener_rule" "clients"{
    for_each = toset(var.clients)
    listener_arn = aws_lb_listener.alb_listener.arn
    priority = 100 + index(var.clients, each.key)
      condition {
        host_header {
          values = ["${each.key}.local"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clients[each.key].arn
  }
}

resource "aws_lb_target_group" "ecs" {
    name = "${var.project_name}-tg-ecs"
    port = 80
    protocol = "HTTP"
    vpc_id = var.vpc_id
    target_type = "ip"
    health_check {
      path ="/"
      protocol = "HTTP"
      interval = 30
      timeout = 5
      healthy_threshold = 2
      unhealthy_threshold = 5
      matcher = "200-399"
    }
}

resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.alb.arn
    port = 8080
    protocol = "HTTP"
    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.ecs.arn
    }
}