# output "instance_public_ips" {
#     value = aws_autoscaling_group.app_asg.instances[*].public_ip
# }
output "asg_name" {
    value= aws_autoscaling_group.app_asg.name
}