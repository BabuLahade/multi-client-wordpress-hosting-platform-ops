output "security_group_ids" {
    value = aws_security_group.alb_sg.id
  
}
# output "alb_security_group_id" {
#     value = aws_security_group.alb_sg.id
# }
# output "app_security_group_id" {
#     value =aws_security_group.app.id
# }
# output "db_security_group_id" {
#     value = aws_security_group.db.id
# }