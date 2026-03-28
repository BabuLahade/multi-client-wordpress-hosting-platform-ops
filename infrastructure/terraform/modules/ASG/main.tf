resource "aws_autoscaling_group" "app_asg_1" {
    name = "${var.project_name}-app-asg-1-"
    desired_capacity = 2
    min_size = 1
    max_size = 4
    vpc_zone_identifier = var.private_app_subnet_ids
    launch_template {
      id = var.launch_template_id_1
      version = "$Latest"
    }
    target_group_arns = [
        var.target_group_arn_1]
}

resource "aws_autoscaling_group" "app_asg_2" {
  name = "${var.project_name}-app-asg-2"
  desired_capacity = 2
  min_size = 1
  max_size = 4
  vpc_zone_identifier = var.private_app_subnet_ids
  launch_template {
    id =var.launch_template_id_2
    version = "$Latest"
  }
  target_group_arns = [var.target_group_arn_2]
}