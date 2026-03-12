resource "aws_s3_bucket" "bucket" {
    bucket = "${var.project_name}-s3bucket"
    # acl    = "private"
    tags = {
        Name = "${var.project_name}-s3bucket"
    }       
}
resource "aws_s3_bucket_versioning" "versioning" {
    bucket = aws_s3_bucket.bucket.id
    versioning_configuration {
       status = "Enabled"
    }
}