resource "aws_subnet" "public_subnet" {
    for_each = var.public_subnet_cidrs
    vpc_id = var.vpc_id
    # count = length(var.public_subnet_cidrs)
    cidr_block = each.value
    # availability_zone = var.availability_zones[count.index]
    availability_zone = each.key
    map_public_ip_on_launch = true
    tags ={
        Name = "${var.project_name}-public-subnet-${each.key}"

    }
}

resource "aws_subnet" "private_app_subnet" {
    for_each = var.private_app_subnet_cidrs
    # count =length(var.private_app_subnet_cidrs)
    vpc_id = var.vpc_id
    cidr_block = each.value
    availability_zone = each.key
    map_public_ip_on_launch = false
    tags ={
        Name = "${var.project_name}-private-app-subnet-${each.key}"

    }
}

resource "aws_subnet" "private_db_subnet" {
    for_each = var.private_db_subnet_cidrs
    # count =length(var.private_db_subnet_cidrs)
    vpc_id = var.vpc_id
    cidr_block = each.value
    availability_zone = each.key
    map_public_ip_on_launch = false     
    tags ={
        Name ="${var.project_name}-private-db-subnet-${each.key }"
    }
}
