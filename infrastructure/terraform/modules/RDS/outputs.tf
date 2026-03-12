output "db_instance_endpoint" {
  value     = module.rds.db_instance_endpoint
  sensitive = true
}
output "db_instance_id" {
  value     = module.rds.db_instance_id
  sensitive = true
}
output "db_instance_port" {
  value     = module.rds.db_instance_port
  sensitive = true
}
output "db_instance_arn" {
  value     = module.rds.db_instance_arn
  sensitive = true
}
output "db_instance_status" {
  value     = module.rds.db_instance_status
  sensitive = true
}