output "nat_public_ips" {
  value = aws_nat_gateway.natgw[*].public_ip
}