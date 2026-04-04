resource "aws_internet_gateway" "igw" {
    vpc_id = var.vpc_id
    tags = {
        Name = "${var.project_name}-igw"
    }
}

resource "aws_eip" "natgw_eip" {
    for_each = var.public_subnet_ids
    # count = length(var.private_app_subnet_ids)
    domain = "vpc"
    tags = {
        Name = "${var.project_name}-natgw-eip-${each.key}"
    }
}

resource "aws_nat_gateway" "natgw" {
        for_each = var.public_subnet_ids
    # count =length(var.public_subnet_ids)
    subnet_id = each.value
    allocation_id = aws_eip.natgw_eip[each.key].id
    tags = {
        Name = "${var.project_name}-natgw-${each.key}"
    }
    depends_on = [aws_internet_gateway.igw]
}