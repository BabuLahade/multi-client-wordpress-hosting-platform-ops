# ── GLOBAL ───────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "wch" # WebcreateHub
}

# variable "environment" {
#   description = "Environment: prod / staging / dev"
#   type        = string
#   default     = "prod"
# }

# ── NETWORK ───────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private subnet CIDRs (RDS + cache)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Private subnet CIDRs (DB only)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

# ── COMPUTE ───────────────────────────────────────────────────
variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 SSH key pair name (must exist in AWS)"
  type        = string
}
variable "availability_zones" {
  description = "List of availability zones for subnets"
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b"]
}
variable "desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling group"
  type        = number
  default     = 1
}
variable "ami_id" {
  description = "AMI ID for the EC2 instances (must be compatible with the instance type and region)"
  type        = string
  default = "ami-073130f74f5ffb161"
}
# ── DATABASE ─────────────────────────────────────────────────
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "wordpress"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

# ── STORAGE ───────────────────────────────────────────────────
variable "s3_media_bucket_name" {
  description = "S3 bucket name for WordPress media (must be globally unique)"
  type        = string
}

variable "s3_backup_bucket_name" {
  description = "S3 bucket name for backups"
  type        = string
}

# ── CLIENTS ───────────────────────────────────────────────────
variable "clients" {
  description = "Map of WordPress client sites"
  type = map(object({
    domain      = string
    db_name     = string
    db_user     = string
    db_password = string
    port        = number
  }))
  default = {}
}
