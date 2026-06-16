output "ecr_repository_url" {
  description = "ECR repository URL (string). Push the api/ image here before each apply."
  value       = aws_ecr_repository.api.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name (string) of the ALB. The k6 BASE_URL and the smoke tests of § VI dial http://<this>:80."
  value       = aws_lb.main.dns_name
}

output "ecs_service_name" {
  description = "ECS service name (string). Use with aws ecs update-service for ad-hoc deployment rollouts."
  value       = aws_ecs_service.api.name
}

output "ecs_cluster_name" {
  description = "ECS cluster name (string). Use with aws ecs describe-tasks for runtime introspection."
  value       = aws_ecs_cluster.main.name
}
