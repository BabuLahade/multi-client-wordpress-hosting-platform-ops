resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}


##### elastic ip for nat gateway
resource "aws_eip" "natgw-eip" {
    domain = "vpc"
    count = length(var.public_subnet_cidrs)
    tags ={
        Name = "${var.project_name}-natgw-eip-${count.index + 1}"

    }
}

#### nat gateway 
resource "aws_nat_gateway" "natgw" {
    allocation_id = aws_eip.natgw-eip.*.id[count.index]
    subnet_id = var.public_subnet_ids[count.index]
    depends_on = [ aws_internet_gateway.igw ]
    count = length(var.public_subnet_cidrs)
    tags ={
        Name = "${var.project_name}-natgw-${count.index + 1}"
    }
}