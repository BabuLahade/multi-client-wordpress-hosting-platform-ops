# variable "project_name" {
#   description = "Name of the project used for tagging resources"
#   type        = string
# }

# variable "vpc_cidr" {
#   description = "CIDR block for the VPC"
#   type        = string
# }

# variable "availability_zones" {
#   description = "List of availability zones"
#   type        = list(string)
# }

# variable "public_subnet_cidrs" {
#   description = "CIDR blocks for public subnets"
#   type        = list(string)
# }

# variable "private_app_subnet_cidrs" {
#   description = "CIDR blocks for private application subnets"
#   type        = list(string)
# }

# variable "private_db_subnet_cidrs" {
#   description = "CIDR blocks for private database subnets"
#   type        = list(string)
# }

# variable "ami_id" {
#   description = "AMI ID for EC2 instances"
#   type        = string
# }

# variable "instance_type" {
#   description = "Instance type for EC2"
#   type        = string
# }

variable "project_name" {
  description = "Name of the project used for tagging resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}
variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets"
  type        = list(string)
}
variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets"
  type        = list(string)
}
variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}
variable "instance_type" {
  description = "Instance type for EC2"
  type        = string
}
variable "key_name" {
  description = "Key pair name for EC2 instances"
  type        = string
} 

variable "db_instance_class" {
  description = "The instance type of the RDS instance (e.g., db.t3.micro)"
  type        = string
}
variable "db_allocated_storage" {
  description = "The allocated storage in gigabytes (e.g., 20)"
  type        = number
}
variable "db_engine" {
    description = "the database engine to use (e.g., mysql, postgres)  "
    type        = string
}
variable "db_engine_version" {
    description = "the version of the database engine (e.g., 8.0 for MySQL)"
    type        = string
}
variable "db_username" {
    description = "the master username for the database"
    type        = string    
    sensitive = true
}
variable "db_password" {
  description = "the master password for the database"
  type        = string
  sensitive = true
}
variable "db_name" {
  description = "the name of the database to create"
  type        = string
}
variable "db_security_group_id" {
  description = "the security group ID to associate with the RDS instance"
  type        = string
  
}
variable "db_subnet_group_name" {
  description = "the name of the DB subnet group to associate with the RDS instance"
  type        = string
}