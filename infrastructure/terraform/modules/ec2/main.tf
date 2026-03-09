resource "aws_ec2_instance" "app" {
    ami =var.ami_id
    instance_type = var.instance_type
    key_name = var.key_name
    vpc_id = aws_vpc.main.id
    subnet_id =aws_subnet.private-app[0].id
    security_group_ids = [aws_security_group.app-sg.id]
    tags = {
        Name = "${var.project_name}-app-instance"
    }   
}   