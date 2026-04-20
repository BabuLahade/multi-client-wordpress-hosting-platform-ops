variable "project_name" {
  description = "Name of the project used for tagging resources"
  type        = string
}
variable "media_bucket_arn" {
  description = "ARN of the S3 bucket for media storage"
  type        = string
}
variable "db_secret_arn" {
  type = string
}