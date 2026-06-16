output "grafana_cloud_role_arn" {
  description = "IAM role ARN (string) to paste into the Grafana Cloud CloudWatch data source's 'Assume Role ARN' field."
  value       = aws_iam_role.grafana_cloud_cw.arn
}

output "api_log_group_name" {
  description = "CloudWatch log group (string) that the api/ service streams stdout/stderr to and that the ADOT sidecar writes its own logs to. Consumed by Module 03 oltp-service task definition."
  value       = aws_cloudwatch_log_group.api.name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name (string). Open at https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=<value>."
  value       = aws_cloudwatch_dashboard.dda.dashboard_name
}

output "adot_container_fragment" {
  description = "ADOT collector container definition fragment (object); consumed by infra/oltp-service when composing the ECS task definition."
  value       = local.adot_container
}
