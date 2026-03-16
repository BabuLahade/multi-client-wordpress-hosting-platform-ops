resource "aws_autoscaling_group" "app_asg" {
    name = "${var.project_name}-app-asg"
    desired_capacity = 2
    min_size = 1
    max_size = 4
    vpc_zone_identifier = var.private_app_subnet_ids
    launch_template {
      id = aws_launch_template.app_launch_template.id
      version = "$Latest"
    }
    target_group_arns = [
        alb_target_group.app_target_group.arn]
}