# output "instance_public_ips" {
#     value = aws_autoscaling_group.app_asg.instances[*].public_ip
# }

output "launch_template_id_1"  {
    value = aws_launch_template.app_launch_template_1.id
}
output "launch_template_id_2" {
    value =aws_launch_template.app_launch_template_2.id
}
output "launch_template"{
    value = aws_launch_template.clients[each.key].id
}