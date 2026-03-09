resource "aws_route_table" "public-rt" {
    vpc_id = var.vpc_id 
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "${var.project_name}-public-rt"
    }
}

resource "aws_route_table" "private-rt" {
    vpc_id = var.vpc_id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id =aws_nat_gateway.natgw[count.index].id
    }
    tags = {
        Name = "${var.project_name}-private-rt"
    }
}

##### subnet associations 
resource "aws_route_table_association" "public-rt-association" {
    count = length(var.public_subnet_ids)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public-rt.id   
}

resource "aws_route_table_association" "private-rt-association" {
    count = length(var.private_app_subnet_ids)
    subnet_id = aws_subnet.private-app[count.index].id
    route_table_id = aws_route_table.private-rt.id
}