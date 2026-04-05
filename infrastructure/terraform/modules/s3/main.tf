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

resource "aws_s3_bucket" "media_bucket" {
    bucket_prefix = "${var.project_name}-media-"
    # bucket_namespace  = "account-regional"
    lifecycle {
      prevent_destroy = false
    }
}
resource "aws_s3_bucket_public_access_block" "public_access_block" {
    bucket = aws_s3_bucket.media_bucket.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls =true
    restrict_public_buckets = true
}
