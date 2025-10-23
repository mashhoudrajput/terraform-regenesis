resource "aws_ecr_repository" "api" {
  name                 = "${local.environment}-${local.service}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${local.environment}-${local.service}-api"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "api_lifecycle" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository" "queue" {
  name                 = "${local.environment}-${local.service}-queue"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${local.environment}-${local.service}-queue"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "queue_lifecycle" {
  repository = aws_ecr_repository.queue.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
