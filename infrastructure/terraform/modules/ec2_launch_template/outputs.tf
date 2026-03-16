resource "aws_launch_template" "app_launch_template" {
    name_prefix = "${var.project_name}-app-launch-template-"
    image_id = var.ami_id
    instance_type = var.instance_type

    key_name = var.key_name
    network_interfaces {
        associate_public_ip_address = true
        security_groups = [var.app_security_group_id]
    }
}