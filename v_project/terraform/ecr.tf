# ==============================================================================
# Amazon ECR Configuration for VProfile Container Images
# Project: VProfile Modern CI/CD (Docker -> ECR -> ECS)
# Author: Ankit Gawade
# ==============================================================================

resource "aws_ecr_repository" "vprofile_app" {
  name                 = "vprofile-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "vprofile-app"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# Lifecycle policy to retain only recent images (preserves AWS Free Tier limits)
resource "aws_ecr_lifecycle_policy" "vprofile_app_policy" {
  repository = aws_ecr_repository.vprofile_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 5 container images"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_repository_url" {
  description = "URL of the Amazon ECR repository"
  value       = aws_ecr_repository.vprofile_app.repository_url
}
