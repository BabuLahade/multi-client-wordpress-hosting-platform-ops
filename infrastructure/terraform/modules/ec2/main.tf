resource "aws_instance" "app" {
    ami =var.ami_id
    instance_type = var.instance_type
    key_name = var.key_name
    vpc_id = var.vpc_id
    subnet_id =var.subnet_id
    security_group_ids = [aws_security_group.alb_sg.id]
    tags = {
        Name = "${var.project_name}-app-instance"
    }   
}   