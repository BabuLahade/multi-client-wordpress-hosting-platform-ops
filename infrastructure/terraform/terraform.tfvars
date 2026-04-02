# private_app_subnet_cidrs = ["10.0.2.0/24", "10.0.3.0/24"]
# private_db_subnet_cidrs  = ["10.0.4.0/24", "10.0.5.0/24"]
# key_name = "aws-project"

# db_username = "admin"
# db_password = "StrongPassword123!"

# s3_media_bucket_name  = "wch-media-12345"
# s3_backup_bucket_name = "wch-backups-12345"
# project_name = "wordpress-hosting"

# vpc_cidr = "10.0.0.0/16"

# availability_zones = [
#   "ap-south-1a",
#   "ap-south-1b"
# ]

# public_subnet_cidrs = [
#   "10.0.1.0/24",
#   "10.0.2.0/24"
# ]

# private_app_subnet_cidrs = [
#   "10.0.3.0/24",
#   "10.0.4.0/24"
# ]

# private_db_subnet_cidrs = [
#   "10.0.5.0/24",
#   "10.0.6.0/24"
# ]

# ami_id = "ami-xxxxxxxx"
# instance_type = "t3.micro"

##############################
project_name             = "wordpress-hosting"
vpc_cidr                 = "10.0.0.0/16"
availability_zones       = ["eu-north-1a", "eu-north-1b"]
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]
key_name = "aws-project"
ami_id = "ami-073130f74f5ffb161"
instance_type = "t3.micro"
db_allocated_storage = 20
db_instance_class = "db.t3.micro"   
db_engine = "mysql"
db_engine_version = "8.0"
db_username = "admin"
db_password = "StrongPassword123!"
db_name = "wordpress"
ec2_clients =["client1","client2"]
ecs_clients = ["client3"]