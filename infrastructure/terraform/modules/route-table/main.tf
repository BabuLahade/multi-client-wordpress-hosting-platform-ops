resource "aws_route_table" "public-rt" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "${var.project_name}-public-rt"
    }
}

resource "aws_route_table" "private-rt" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id =aws_nat_gateway.natgw.[cpunt.index].id
    }
    tags = {
        Name = "${var.project_name}-private-rt"
    }
}

##### subnet associations 
resource "aws_route_table_association" "public-rt-association" {
    count = var.public_subnet_count
    subnet_id = aws_subnet.public.[count.index].id
    route_table_id = aws_route_table.public-rt.id   
}

resource "aws_route_table_association" "private-rt-association" {
    count = var.private_subnet_count
    subnet_id = aws_subnet.private.[count.index].id
    route_table_id = aws_route_table.private-rt.id
}