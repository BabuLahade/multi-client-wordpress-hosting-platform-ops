# # # ____________VPC MODULE____________
# # module "vpc" {
# #   source = "./modules/vpc"
# #   project_name = var.project_name
# #   cidr_block = var.vpc_cidr
# # }

# # # ____________SUBNET MODULE____________
# # # module "subnet" {
# # #   source = "./modules/subnet"
# # #   vpc_id = module.vpc.vpc_id
# # #   public_subnet_cidrs = var.public_subnet_cidrs
# # #   private_app_subnet_cidrs = var.private_app_subnet_cidrs   
# # # }
# # # module "subnet" {
# # #   source        = "./modules/subnet"
# # #   project       = var.project
# # # #   environment   = var.environment
# # #   vpc_id        = module.vpc.vpc_id
# # #   public_cidrs  = var.public_subnet_cidrs
# # #   private_cidrs = var.private_subnet_cidrs
# # # }


# # module "igw_natgw" {
# #   source = "./modules/igw-natgw"
# #   vpc_id = module.vpc.vpc_id
# #   project_name = var.project_name
# #   public_subnet_id = module.subnet.public_subnet_ids[0]
# #   availability_zone = var.availability_zones[0]
# #   private_app_subnet_ids = module.subnet.private_app_subnet_ids
# #   public_subnet_cidrs = var.public_subnet_cidrs
# #   public_subnet_ids = module.subnet.public_subnet_ids
# # }
# # module "route_table" {
# #   source = "./modules/route-table"
# #   vpc_id = module.vpc.vpc_id
# #   project_name = var.project_name
# #   public_subnet_ids = module.subnet.public_subnet_ids
# #   private_app_subnet_ids = module.subnet.private_app_subnet_ids
# # }
# # module "security_group" {
# #   source = "./modules/security-group"
# #   project_name = var.project_name
# # }
# # module "subnet" {
# #   source = "./modules/subnet"
# #   vpc_id = module.vpc.vpc_id
# #   project_name = var.project_name
# #   public_subnet_cidrs = var.public_subnet_cidrs
# #   private_app_subnet_cidrs = var.private_app_subnet_cidrs
# #   private_db_subnet_cidrs = var.private_db_subnet_cidrs
# #   availability_zones = var.availability_zones
# # }
# # module "ec2" {
# #   source = "./modules/ec2"
# #   project_name = var.project_name
# #   ami_id = var.ami_id
# #   instance_type = var.ec2_instance_type
# #   key_name = var.key_name
# # }
# # ____________VPC MODULE____________
# module "vpc" {
#   source = "./modules/vpc"
#   project_name = var.project_name
#   cidr_block = var.vpc_cidr
# }

# # ____________SUBNET MODULE____________
# # module "subnet" {
# #   source = "./modules/subnet"
# #   vpc_id = module.vpc.vpc_id
# #   public_subnet_cidrs = var.public_subnet_cidrs
# #   private_app_subnet_cidrs = var.private_app_subnet_cidrs   
# # }
# # module "subnet" {
# #   source        = "./modules/subnet"
# #   project       = var.project
# # #   environment   = var.environment
# #   vpc_id        = module.vpc.vpc_id
# #   public_cidrs  = var.public_subnet_cidrs
# #   private_cidrs = var.private_subnet_cidrs
# # }


# module "igw_natgw" {
#   source = "./modules/igw-natgw"
#   vpc_id = module.vpc.vpc_id
#   project_name = var.project_name
#   public_subnet_id = module.subnet.public_subnet_ids[0]
#   availability_zone = var.availability_zones[0]
#   private_app_subnet_ids = module.subnet.private_app_subnet_ids
#   public_subnet_cidrs = var.public_subnet_cidrs
#   public_subnet_ids = module.subnet.public_subnet_ids
# }
# module "route_table" {
#   source = "./modules/route-table"
#   vpc_id = module.vpc.vpc_id
#   project_name = var.project_name
#   public_subnet_ids = module.subnet.public_subnet_ids
#   private_app_subnet_ids = module.subnet.private_app_subnet_ids
# }
# module "security_group" {
#   source = "./modules/security-group"
#   project_name = var.project_name
# }
# module "subnet" {
#   source = "./modules/subnet"
#   vpc_id = module.vpc.vpc_id
#   project_name = var.project_name
#   public_subnet_cidrs = var.public_subnet_cidrs
#   private_app_subnet_cidrs = var.private_app_subnet_cidrs
#   private_db_subnet_cidrs = var.private_db_subnet_cidrs
#   availability_zones = var.availability_zones
# }
# module "ec2" {
#   source = "./modules/ec2"
#   project_name = var.project_name
#   ami_id = var.ami_id
#   instance_type = var.ec2_instance_type
#   key_name = var.key_name
# }

# ---------- VPC ----------
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  cidr_block   = var.vpc_cidr
}

# ---------- SUBNET ----------
module "subnet" {
  source = "./modules/subnet"

  vpc_id =module.vpc.vpc_id
  project_name             = var.project_name
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  availability_zones       = var.availability_zones
}

# ---------- IGW + NAT ----------
module "igw_natgw" {
  source = "./modules/igw-natgw"

  vpc_id                 = module.vpc.vpc_id
  project_name           = var.project_name
  public_subnet_id       = module.subnet.public_subnet_ids[0]
  availability_zone      = var.availability_zones[0]
  private_app_subnet_ids = module.subnet.private_app_subnet_ids
  public_subnet_cidrs    = var.public_subnet_cidrs
  public_subnet_ids      = module.subnet.public_subnet_ids
}

# ---------- ROUTE TABLE ----------
module "route_table" {
  source = "./modules/route-table"

  vpc_id = module.vpc.vpc_id
  project_name           = var.project_name
  public_subnet_ids      = module.subnet.public_subnet_ids
  private_app_subnet_ids = module.subnet.private_app_subnet_ids
}

# ---------- SECURITY GROUP ----------
module "security_group" {
  source = "./modules/security-group"

  project_name = var.project_name
}

# ---------- EC2 ----------
module "ec2" {
  source = "./modules/ec2"

  project_name  = var.project_name
  ami_id        = var.ami_id
  instance_type = var.ec2_instance_type
  key_name      = var.key_name
}