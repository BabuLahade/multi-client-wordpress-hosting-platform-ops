variable "project_name" {
  description = "name of our project "
  type =string
}

variable "private_app_subnet_cidrs" {
  description = "value"
  type = list(string)
}