# output "instance_public_ips" {
#     value = aws_autoscaling_group.app_asg.instances[*].public_ip
# }
output "asg_name_1" {
    value= aws_autoscaling_group.app_asg_1.name
}

output "asg_name_2" {
    value =aws_autoscaling_group.app_asg_2.name
}