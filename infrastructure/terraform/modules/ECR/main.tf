resource "aws_ecr_repository" "wordpress_repo" {
    name = "${var.project_name}-ecr-repo"
    image_tag_mutability = "MUTABLE"
    image_scanning_configuration {
        scan_on_push = true
    }
}

#we will only use 5 docke images latest
resource "aws_ecr_lifecycle_policy" "wordpress_repo_lifecycle" {
    repository = aws_ecr_repository.wordpress_repo.name
    policy =  jsonencode({
        rules =[ {
            rulePriority = 1
            description = "Keep only 5 latest images"
            selection = {
                tagStatus = "any"
                countType = "imageCountMoreThan"
                countNumber = 5
            }
            action = {
                type = "expire"
            }
        }]

    })
}
