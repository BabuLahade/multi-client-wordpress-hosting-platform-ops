variable "vpc_id" {
  type        = string
  description = "VPC where internet gateway will be attached"
}

variable "project_name" {
  type = string
}

# variable "public_subnet_id" {
#   type        = map(string)
#   description = "Public subnet where NAT gateway will be deployed"
# }
# variable "availability_zones" {
#   type        = list(string)
#   description = "Availability zones for the NAT gateway"
# }
# variable "private_app_subnet_ids" {
#   type        = map(string)
#   description = "List of private application subnet IDs to associate with the route table"
# }
# variable "public_subnet_cidrs" {
#   type = map(string)
# }
variable "public_subnet_ids" {
  type = map(string)
}   