output "public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = aws_nat_gateway.natgw.*.public_ip
}   
output "nat_public_ips" {
  value = module.igw_natgw.nat_public_ips
}