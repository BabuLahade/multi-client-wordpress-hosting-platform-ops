output "nat_public_ips" {
  # value = aws_nat_gateway.natgw[*].public_ip
  value = {
    for k, v in aws_nat_gateway.natgw : k => v.public_ip
  }
}
output "igw_id" {
  

   value = aws_internet_gateway.igw.id
}
output "natgw_ids" {
  value = {
    for k, v in aws_nat_gateway.natgw : k => v.id
  }
}