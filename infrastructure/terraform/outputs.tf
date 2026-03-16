# # ── CONNECT INFO ─────────────────────────────────────────────
# output "ssh_command" {
#   description = "SSH into EC2"
#   value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2.public_ip}"
# }

# output "ip_address" {
#     value = module.ec2.public_ip

# }

# output "alb_dns_name" {
#   description = "Point all client domains here (CNAME)"
#   value       = module.alb.alb_dns_name
# }

# output "rds_endpoint" {
#   value     = module.rds.rds_endpoint
#   sensitive = true
# }

# output "s3_media_bucket" {
#   value = module.s3.media_bucket_name
# }

# output "s3_backup_bucket" {
#   value = module.s3.backup_bucket_name
# }

# # ── DNS SETUP INSTRUCTIONS ───────────────────────────────────
# output "dns_instructions" {
#   description = "Point each client domain to the ALB"
#   value = join("\n", [
#     for name, client in var.clients :
#     "${client.domain}  →  CNAME  →  ${module.alb.alb_dns_name}"
#   ])
# }

# output "public_ip" {
#     value = module.ec2.public_ip
# }
# output "vpc_id" {
#     value = module.vpc.vpc_id
# }


output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.subnet.public_subnet_ids
}
output "private_app_subnet_ids" {
  value = module.subnet.private_app_subnet_ids
}
output "private_db_subnet_ids" {
  value = module.subnet.private_db_subnet_ids
}
output "igw_id" {
  value = module.igw_natgw.igw_id
}
output "natgw_ids" {
  value = module.igw_natgw.natgw_ids
}
output "public_route_table_id" {
  value = module.route_table.public_route_table_id
}
output "private_route_table_ids" {
  value = module.route_table.private_route_table_ids
}

# output "ec2_public_ips" {
#   description = "Public IPs of EC2 instances"
#   value       = module.ec2.instance_public_ips
# }
output "db_instance_endpoint" {
  description = "value"
  value = module.rds.db_instance_endpoint
}
output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "launch_template_id" {
  value = module.launch_template.launch_template_id
}

output "asg_name" {
  value = module.asg.asg_name
}