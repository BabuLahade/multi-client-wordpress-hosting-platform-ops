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
    source = "./modules/vpc"
    project_name = var.project_name
    vpc_cidr = var.vpc_cidr
}

module "subnet" {
    source = "./modules/subnet"
    project_name = var.project_name
    vpc_id = module.vpc.vpc_id
    vpc_cidr = var.vpc_cidr
    public_subnet_ids = module.subnet.public_subnet_ids
    private_app_subnet_ids = module.subnet.private_app_subnet_ids    
    private_db_subnet_ids = module.subnet.private_db_subnet_ids
    public_subnet_cidrs  = var.public_subnet_cidrs  
    private_app_subnet_cidrs  = var.private_app_subnet_cidrs
    private_db_subnet_cidrs   = var.private_db_subnet_cidrs 
    availability_zones   = var.availability_zones

}