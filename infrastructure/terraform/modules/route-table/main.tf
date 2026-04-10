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
  for_each = var.private_app_subnet_ids
  # count  = length(var.private_app_subnet_ids)
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.natgw_ids[each.key]
  }

  tags = {
    Name = "${var.project_name}-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private_assoc" {
  for_each = var.private_app_subnet_ids
  # count          = length(var.private_app_subnet_ids)
  subnet_id      = var.private_app_subnet_ids[each.key]
  route_table_id = aws_route_table.private_rt[each.key].id
}

resource "aws_route_table_association" "public_rt_assoc" {
    for_each = var.public_subnet_ids
    # count = length(var.public_subnet_ids)
    subnet_id = var.public_subnet_ids[each.key]
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_vpc_endpoint" "s3" {
    vpc_id = var.vpc_id
    service_name = "com.amazonaws.eu-north-1.s3"

    route_table_ids = [
        for rt in aws_route_table.private_rt : rt.id
    ]
    tags = {
    Name = "${var.project_name}-s3-free-tunnel"
  }
}