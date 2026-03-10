variable "project_name" {
    description = "The name of the project, used for tagging resources"
    type = string
}

variable "vpc_id" {
    description = "VPC ID for subnet"
    type        = string
}
variable "vpc_cidr" {
    description = "VPC CIDR block"
    type        = string
}
variable "public_subnet_cidrs" {
    description = "CIDR block for the public subnet"
    type        = list(string)
}
variable "private_app_subnet_cidrs" {
    description = "CIDR block for the private application subnet"
    type        = list(string)
}
variable "private_db_subnet_cidrs" {
    description = "CIDR block for the private database subnet"
    type        = list(string)
}
variable "availability_zones" {
    description = "Availability zones for the subnets"
    type        = list(string)
}
variable "public_subnet_ids" {
    description = "List of public subnet IDs to associate with the route table"
    type        = list(string)
}
variable "private_app_subnet_ids" {
    description = "List of private application subnet IDs to associate with the route table"
    type        = list(string)
}
variable "private_db_subnet_ids" {
    description = "List of private database subnet IDs to associate with the route table"
    type        = list(string)
}