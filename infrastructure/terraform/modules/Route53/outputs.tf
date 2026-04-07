output "nameservers" {
    value = aws_route53_zone.main.name_servers
    description = "The nameservers for the Route53 hosted zone"
  
}

output "zone_id" {
    value = aws_route53_zone.main.zone_id
    description = "The ID of the Route53 hosted zone"
}