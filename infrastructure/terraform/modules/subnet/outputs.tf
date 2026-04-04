output "public_subnet_ids" {
    value = {
        for k , v in aws_subnet.public_subnet : k=>v.id
    }
}
output "private_app_subnet_ids" {
    # value = aws_subnet.private_app_subnet.*.id
    value = {
        for k , v in aws_subnet.private_app_subnet : k=>v.id
    }
}
# output "vpc_id" {
#     value = aws_vpc.main.id
# }
output "private_db_subnet_ids" {
    # value = aws_subnet.private_db_subnet.*.id
    value = {
        for k , v in aws_subnet.private_db_subnet :  k => v.id
    }
}
output "public_subnet_cidrs" {
    value = aws_subnet.public_subnet.*.cidr_block
}
output "private_app_subnet_cidrs" {
    value = aws_subnet.private_app_subnet.*.cidr_block
}
output "private_db_subnet_cidrs" {
    value = aws_subnet.private_db_subnet.*.cidr_block
}
