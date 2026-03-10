output "nat_public_ips" {
  value = aws_nat_gateway.natgw[*].public_ip
}
output "igw_id" {
  value = aws_internet_gateway.igw.id
}
output "natgw_ids" {
  value = aws_nat_gateway.natgw[*].id
}