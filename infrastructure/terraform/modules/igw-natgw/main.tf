resource "aws_internet_gateway" "igw" {
    vpc_id = var.vpc_id
    tags = {
        Name = "${var.project_name}-igw"
    }
}

resource "aws_eip" "natgw_eip" {
    count = length(var.private_app_subnet_ids)
    domain = "vpc"
    tags = {
        Name = "${var.project_name}-natgw-eip-${count.index + 1}"
    }
}

resource "aws_nat_gateway" "natgw" {
    count =length(var.public_subnet_ids)
    subnet_id = var.public_subnet_ids[count.index]
    allocation_id = aws_eip.natgw_eip[count.index].id
    tags = {
        Name = "${var.project_name}-natgw-${count.index +1}"
    }
}