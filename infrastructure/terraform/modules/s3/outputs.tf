output "bucket" {
    value = aws_s3_bucket.bucket.bucket
}
output "bucket_name" {
    value = aws_s3_bucket.media_bucket.id
}

output "media_bucket_arn" {
    value = aws_s3_bucket.media_bucket.arn
}