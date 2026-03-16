resource "aws_autoscaling_group" "app_asg" {
    name = "${var.project_name}-app-asg"
    desired_capacity = 2
    min_size = 1
    max_size = 4
    vpc_zone_identifier = var.private_app_subnet_ids
    launch_template {
      id = var.launch_template_id
      version = "$Latest"
    }
    target_group_arns = [
        var.target_group_arn]
}