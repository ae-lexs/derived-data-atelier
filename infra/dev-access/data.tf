data "terraform_remote_state" "data_model" {
  backend = "s3"

  config = {
    bucket  = "dda-tfstate-795805281797"
    key     = "data-model/terraform.tfstate"
    region  = "us-east-1"
    profile = "derived-data-atelier"
  }
}

# Resolve the latest Amazon Linux 2023 ARM64 AMI via the AWS-maintained SSM
# parameter. Combined with `lifecycle.ignore_changes = [ami]` on the bastion
# below, this keeps the AMI ID fresh on `apply` without forcing replacement
# whenever AWS publishes a new patch.
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}
