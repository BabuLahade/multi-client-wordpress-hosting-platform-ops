resource "aws_route_table" "public_rt" {
    vpc_id = var.vpc_id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = var.igw_id
    }
    tags = {
        Name = "${var.project_name}-public-rt"
    }
}

resource "aws_route_table" "private_rt" {
  count  = length(var.private_app_subnet_ids)
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.natgw_ids[count.index]
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index}"
  }
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(var.private_app_subnet_ids)
  subnet_id      = var.private_app_subnet_ids[count.index]
  route_table_id = aws_route_table.private_rt[count.index].id
}

resource "aws_route_table_association" "public_rt_assoc" {
    count = length(var.public_subnet_ids)
    subnet_id = var.public_subnet_ids[count.index]
    route_table_id = aws_route_table.public_rt.id
}

