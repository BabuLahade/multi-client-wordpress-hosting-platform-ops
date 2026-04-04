output "public_route_table_id" {
  value = aws_route_table.public_rt.id
}

output "private_route_table_ids" {
  value = {
    for k, v in aws_route_table.private_rt : k => v.id
  }
}
