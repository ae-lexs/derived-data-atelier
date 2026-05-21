output "bastion_instance_id" {
  description = "EC2 instance ID of the bastion (string). Used as the --target of `aws ssm start-session`."
  value       = aws_instance.bastion.id
}

output "port_forward_command" {
  description = "Ready-to-run AWS CLI command (string) that opens a port forward from localhost:5432 to Aurora through the bastion. Requires the Session Manager Plugin on the host."
  value = format(
    "aws ssm start-session --profile derived-data-atelier --target %s --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters host=%s,portNumber=5432,localPortNumber=5432",
    aws_instance.bastion.id,
    data.terraform_remote_state.data_model.outputs.cluster_endpoint,
  )
}
