output "public_subnet_ids" {
    value = aws_subnet.public.*.id
}
output "private_app_subnet_ids" {
    value = aws_subnet.private
}
output "vpc_id" {
    value = aws_vpc.main.id
}
output "private_db_subnet_ids" {
    value = aws_subnet.private-db.*.id
}
output "public_subnet_cidrs" {
    value = aws_subnet.public.*.cidr_block
}
output "private_app_subnet_cidrs" {
    value = aws_subnet.private-app.*.cidr_block
}
output "private_db_subnet_cidrs" {
    value = aws_subnet.private-db.*.cidr_block
}