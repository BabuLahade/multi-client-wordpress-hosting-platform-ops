output "igw_id" {
    value = aws_internet_gateway.igw.id
}
output "natgw_ids" {
    value = aws_nat_gateway.natgw[*].id
}
# output "vpc_id" {
#     value = var.vpc_id
# }