variable "project_name" {
    description = "The name of the project, used for tagging and naming resources"
    type        = string
}
variable "private_db_subnet_ids" {
    description = "List of subnet IDs for the DB subnet group"
    type        = map(string)
}
variable "redis_security_group_id" {
    description = "value"
    type = value 
    
}