resource "aws_subnet" "public_subnet" {
    vpc_id = var.vpc_id
    count = length(var.public_subnet_cidrs)
    cidr_block = var.public_subnet_cidrs[count.index]
    availability_zone = var.availability_zones[count.index]
    map_public_ip_on_launch = true
    tags ={
        Name = "${var.project_name}-public-subnet-${count.index + 1}"

    }
}

resource "aws_subnet" "private_app_subnet" {
    count =length(var.private_app_subnet_cidrs)
    vpc_id = var.vpc_cidr
    cidr_block = var.private_app_subnet_cidrs[count.index]
    availability_zone = var.availability_zones[count.index]
    map_public_ip_on_launch = false
    tags ={
        Name = "${var.project_name}-private-app-subnet-${count.index + 1}"

    }
}

resource "aws_subnet" "private_db_subnet" {
    count =length(var.private_db_subnet_cidrs)
    vpc_id = var.vpc_cidr
    cidr_block = var.private_db_subnet_cidrs[count.index]
    availability_zone = var.availability_zones[count.index]
    map_public_ip_on_launch = false     
    tags ={
        Name ="${var.project_name}-private-db-subnet-${count.index + 1 }"
    }
}
