variable "project_name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

# variable "private_app_subnet_ids" {
#   type = list(string)
# }

variable "security_group_id" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}