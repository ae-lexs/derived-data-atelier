variable "grafana_cloud_account_id" {
  type        = string
  description = "Grafana Cloud's AWS account ID — the principal allowed to STS:AssumeRole into the CloudWatch read-only role created here. Doc V.4 cites 008923505280 (May 2026); Grafana has rotated this before, so verify against https://grafana.com/docs/grafana-cloud/account-management/authentication/ before any real apply."
  default     = "008923505280"
}

variable "grafana_cloud_external_id" {
  type        = string
  description = "External ID generated in the Grafana Cloud UI when the AWS CloudWatch data source is created. Acts as a confused-deputy guard on the STS:AssumeRole. Replace before apply — the default is a placeholder so terraform plan succeeds in the codelab without prompting."
  default     = "REPLACE_BEFORE_APPLY"
}
