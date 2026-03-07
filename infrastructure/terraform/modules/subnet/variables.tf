variable "project_name" {
    description = "project name"
    type = string
}

variable "public_subnet_cidrs" {
    description = "List of CIDR blocks for public subnets"
    type = list(string)
}

variable "private_app_subnet_cidrs" {
    description = "List of CIDR blocks for private application subnets"
    type = list(string)
}
variable "private_db_subnet_cidrs" {
    description = "List of CIDR blocks for private database subnets"
    type = list(string)
}
variable "availability_zones" {
    description = "List of availability zones for subnets"
    type = list(string)
}
