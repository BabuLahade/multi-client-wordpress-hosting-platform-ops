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
    block_public_acls = false
    block_public_policy = false
     ignore_public_acls = false
    # ignore_public_acls =true
    restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.media_bucket.id # UPDATE THIS TO MATCH YOUR RESOURCE NAME
  
  # Terraform must remove the shield BEFORE it applies the policy
  depends_on = [aws_s3_bucket_public_access_block.public_access_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.media_bucket.arn}/*" # UPDATE THIS TO MATCH YOUR RESOURCE NAME
      }
    ]
  })
}