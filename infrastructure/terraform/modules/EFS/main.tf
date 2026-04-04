resource "aws_efs_file_system" "wordpress" {
    creation_token = "${var.project_name}-efs"
    performance_mode = "generalPurpose"
    throughput_mode = "elastic"
    tags = {
        Name = "${var.project_name}-efs"
    }
}

resource "aws_efs_mount_target" "efs_mount" {
  for_each =var.private_app_subnet_ids
  file_system_id = aws_efs_file_system.wordpress.id
  subnet_id = each.value
  security_groups = [var.efs_security_group_id]
}