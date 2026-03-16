# output "instance_public_ips" {
#     value = aws_autoscaling_group.app_asg.instances[*].public_ip
# }

output "launch_template_id"  {
    value = aws_launch_template.app_launch_template.id
}