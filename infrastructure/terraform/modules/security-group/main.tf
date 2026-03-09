### security group for ALB
resource "aws_security_group" "alb-sg" {
    name = "${var.project_name}-alb-sg"
    description = "Security group for ALB"
    vpc_id =aws_vpc.main.id
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port =443
        to_port =443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.project_name}-alb-sg"
    }
}

#########  Security group for application servers (EC2 instances)
resource "aws_security_group" "app-sg" {
    name = "${var.project_name}-app-sg"
    description = "Security group for application servers"
    vpc_id = aws_vpc.main.id
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.alb-sg.id]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"] 
    }
    tags = {
        Name = "${var.project_name}-app-sg"
    }
}

##### datsabase security group
resource "aws_security_group" "db-sg" {
    name = "${var.project_name}-db-sg"
    description = "Security group for database servers"
    vpc_id = var.vpc_id
    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = [aws_security_group.app-sg.id]
    }
    tags = {
        Name = "${var.project_name}-db-sg"
    }
}