output "cluster_endpoint" {
  description = "Aurora writer endpoint hostname (string). Consumed by golang-migrate and by every module from Module 02 onward."
  value       = aws_rds_cluster.main.endpoint
}

output "private_subnet_ids" {
  description = "Private subnet IDs across both AZs (list(string)). Used by the DB subnet group and by future Fargate placement (Module 03+)."
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "secret_arn" {
  description = "Master-credentials secret ARN (string). Module 02 rotates the api/ service onto IAM auth; for Module 01 the secret is the only path."
  value       = aws_secretsmanager_secret.master.arn
}

output "vpc_id" {
  description = "VPC ID shared by every DDA module that runs on top of this data substrate (string)."
  value       = aws_vpc.main.id
}

output "cluster_identifier" {
  description = "Aurora cluster identifier. Consumed by Module 04 infra/replica and Module 05 infra/cdc."
  value       = aws_rds_cluster.main.id
}

output "writer_identifier" {
  description = "Aurora writer instance identifier."
  value       = aws_rds_cluster_instance.writer.identifier
}

output "cluster_resource_id" {
  description = "Aurora cluster resource ID (string, dbi-resource-id). Stable for the cluster's lifetime. Used by IAM policies that grant rds-db:connect."
  value       = aws_rds_cluster.main.cluster_resource_id
}
