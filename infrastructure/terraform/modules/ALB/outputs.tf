output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}
output "alb_arn" {
  value = aws_lb.alb.arn
}
# output "target_group_arn_1" {
#   value = aws_lb_target_group.alb_tg_1.arn
# }

# output "target_group_arn_2" {
#   value = aws_lb_target_group.alb_tg_2.arn
# }
output "target_group_arns" {
  value ={
    for k , v in aws_lb_target_group.clients : k => v.arn 
    }
}
output "target_group_arn" {
  value ={
  for k , v in aws_lb_target_group.client1_tg_ecs : k => v.arn
}
}
# output "target_group_arn" {
#   value = aws_lb_target_group.client1_tg_ecs["client1"].arn
# }
output "alb_arn_suffix" {
  value = aws_lb.alb.arn_suffix
  }