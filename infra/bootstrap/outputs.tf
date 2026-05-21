output "account_id" {
  description = "AWS account ID this bootstrap targeted (string). Referenced when configuring backend blocks in sibling modules."
  value       = data.aws_caller_identity.current.account_id
}

output "state_bucket_name" {
  description = "S3 bucket holding Terraform remote state for every DDA root module (string)."
  value       = aws_s3_bucket.tf_state.id
}

output "state_lock_table_name" {
  description = "DynamoDB table used by the S3 backend for state-locking (string)."
  value       = aws_dynamodb_table.tf_lock.name
}
