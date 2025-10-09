resource "aws_ecr_repository" "api" {
  name                 = "dev-regenesis-api"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "dev-regenesis-api" }
}

resource "aws_ecr_repository" "queue" {
  name                 = "dev-regenesis-queue"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "dev-regenesis-queue" }
}
