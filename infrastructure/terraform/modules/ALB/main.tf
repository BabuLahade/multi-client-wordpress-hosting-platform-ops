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