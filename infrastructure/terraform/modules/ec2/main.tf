resource "aws_instance" "app_instance" {

  count = length(var.private_app_subnet_ids)

  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id = var.private_app_subnet_ids[count.index]

  vpc_security_group_ids = [var.security_group_id]

  tags = {
    Name = "${var.project_name}-app-instance-${count.index + 1}"
  }
}