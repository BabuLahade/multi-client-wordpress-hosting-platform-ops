output "repository_url" {
    value = aws_ecr_repository.wordpress_repo.repository_url
    description = "URL of the ECR repository"
}