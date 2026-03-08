variable "project_name" {
  description = "name of our project "
  type =string
}

variable "private_app_subnet_ids" {
  description = "value"
  type = list(string)
}
variable "public_subnet_ids" {
  description = "value"
  type = list(string)
}