variable "project_name" {
  type = string
}
variable "public_subnet_ids" {
  type = map(string)
}
variable "alb_security_group_id" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "ec2_clients"{
  type =list(string)
}
variable "ecs_clients" {
  type = list(string)
}