output "route_table_id" {
    value = aws_route_table.private_rt.id
}   
output "public_route_table_id" {
    value = aws_route_table.public_rt.id
}
output "private_app_route_table_id" {
    value = aws_route_table.private_app_rt.id
}
