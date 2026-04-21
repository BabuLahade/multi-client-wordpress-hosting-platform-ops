resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = values(var.private_db_subnet_ids)

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}
resource "aws_db_instance" "wordpress_db"{
    allocated_storage = var.db_allocated_storage
    engine = var.db_engine
    engine_version = var.db_engine_version
    instance_class = var.db_instance_class
    identifier = "${var.project_name}-db-instance"
    username = var.db_username
    # password = var.db_password
    password = var.secret_db_password
    db_name = var.db_name
    vpc_security_group_ids = [var.db_security_group_id]
    db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
    backup_retention_period = 7
    backup_window           = "03:00-04:00"
    copy_tags_to_snapshot   = true
    skip_final_snapshot = true  
    multi_az = true 
    publicly_accessible = false
    tags = {
        Name = "${var.project_name}-db-instance"
    }   
}


 