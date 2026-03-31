# module "vpc" {
#   source       = "./modules/vpc"
#   project_name = var.project_name
#   vpc_cidr     = var.vpc_cidr
# }
# module "subnet" {
#   source = "./modules/subnet"
#   project_name = var.project_name
#   vpc_id = module.vpc.vpc_id
#   vpc_cidr = var.vpc_cidr
#   public_subnet_cidrs  = var.public_subnet_cidrs
#   private_app_subnet_cidrs  = var.private_app_subnet_cidrs
#   private_db_subnet_cidrs   = var.private_db_subnet_cidrs
#   availability_zones        = var.availability_zones
# }

# module "igw_natgw" {
#   source = "./modules/igw-natgw"
#   project_name = var.project_name
#   vpc_id  = module.vpc.vpc_id
# }

# module "route_table" {
#   source = "./modules/route-table"

#   project_name = var.project_name
#   vpc_id       = module.vpc.vpc_id

#   igw_id      = module.igw_natgw.igw_id
#   natgw_ids   = module.igw_natgw.natgw_ids

#   public_subnet_ids      = module.subnets.public_subnet_ids
#   private_app_subnet_ids = module.subnets.private_app_subnet_ids
#   private_db_subnet_ids  = module.subnets.private_db_subnet_ids
# }

# module "security_group" {
#   source       = "./modules/security-group"
#   project_name = var.project_name
#   vpc_id       = module.vpc.vpc_id
#   description  = "Security group for app instances"
# }

# module "ec2" {
#   source = "./modules/ec2"

#   project_name           = var.project_name
#   private_app_subnet_ids = module.subnets.private_app_subnet_ids
#   ami_id                 = var.ami_id
#   instance_type          = var.instance_type
#   security_group_id      = module.security_group.security_group_id
# }

##########################################################

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "subnet" {
  source       = "./modules/subnet"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
  # public_subnet_ids = module.subnet.public_subnet_ids
  # private_app_subnet_ids = module.subnet.private_app_subnet_ids    
  # private_db_subnet_ids = module.subnet.private_db_subnet_ids
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  availability_zones       = var.availability_zones

}

module "igw_natgw" {
  source = "./modules/igw-natgw"
  # eip_allocation_ids = module.igw_natgw.eip_allocation_ids
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  # vpc_cidr = var.vpc_cidr
  public_subnet_id  = module.subnet.public_subnet_ids
  availability_zones = var.availability_zones
  # private_db_subnet_ids = module.subnet.private_db_subnet_ids
  private_app_subnet_ids = module.subnet.private_app_subnet_ids
  public_subnet_cidrs    = var.public_subnet_cidrs
  public_subnet_ids      = module.subnet.public_subnet_ids
}

module "route_table" {
  source                 = "./modules/route-table"
  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  igw_id                 = module.igw_natgw.igw_id
  natgw_ids              = module.igw_natgw.natgw_ids
  public_subnet_ids      = module.subnet.public_subnet_ids
  private_app_subnet_ids = module.subnet.private_app_subnet_ids
  private_db_subnet_ids  = module.subnet.private_db_subnet_ids

}

module "security_group" {
  source = "./modules/security-group"
  project_name = var.project_name
  vpc_id = module.vpc.vpc_id
}

# module "ec2" {
#   source = "./modules/ec2"
#   project_name = var.project_name
#   public_subnet_ids = module.subnet.public_subnet_ids
#   ami_id = var.ami_id
#   key_name = var.key_name
#   instance_type = var.instance_type
# #   subnet_id = module.subnet.private_app_subnet_ids[count.index] 
#   security_group_id = module.security_group.security_group_ids
# }

module "s3" {
  source = "./modules/s3"
  project_name = var.project_name
}


module "rds" { 
  source = "./modules/RDS"
  project_name = var.project_name
  db_instance_class = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_engine = var.db_engine
  db_engine_version = var.db_engine_version
  db_username = var.db_username
  db_password = var.db_password
  db_name = var.db_name
  private_db_subnet_ids = module.subnet.private_db_subnet_ids
  db_security_group_id = module.security_group.db_security_group_id
  # db_subnet_group_name = module.rds.db_subnet_group_name
}
module "IAM" {
  source = "./modules/IAM"
  project_name = var.project_name
}
module "launch_template" {
  source = "./modules/ec2_launch_template"

  project_name = var.project_name
  ami_id = var.ami_id
  instance_type = var.instance_type
  key_name = var.key_name
  clients = var.clients
  app_security_group_id = module.security_group.app_security_group_id
  iam_instance_profile_name = module.IAM.iam_instance_profile_name
  # db_instance_endpoint = module.rds.db_instance_endpoint
  db_instance_address = module.rds.db_instance_address
}

module "alb" {
  source = "./modules/ALB"

  project_name = var.project_name
  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.subnet.public_subnet_ids
  alb_security_group_id = module.security_group.alb_security_group_id
  clients = var.clients

}

module "asg" {
  source = "./modules/ASG"

  project_name = var.project_name
  vpc_id = module.vpc.vpc_id
  private_app_subnet_ids = module.subnet.private_app_subnet_ids
  clients = var.clients
  launch_template_ids =  module.launch_template.launch_template_ids
  target_group_arn = module.alb.target_group_arn
  # target_group_arn_1 = module.alb.target_group_arn_1
  # target_group_arn_2 = module.alb.target_group_arn_2
  # launch_template_id_1= module.launch_template.launch_template_id_1
  # launch_template_id_2 = module.launch_template.launch_template_id_2
}