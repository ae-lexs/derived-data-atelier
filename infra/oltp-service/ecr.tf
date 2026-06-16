resource "aws_ecr_repository" "api" {
  name                 = "dda-api"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # codelab discipline: terraform destroy wipes images too

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "api_keep_last_5" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the 5 most recent images; older builds are reproducible from git."
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}
