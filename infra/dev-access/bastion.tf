resource "aws_iam_role" "bastion" {
  name = "dda-bastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "dda-bastion"
  role = aws_iam_role.bastion.name
}

resource "aws_security_group" "bastion" {
  name        = "dda-bastion"
  description = "Bastion outbound only (SSM endpoints, Aurora 5432). No inbound; SSM uses outbound-initiated sessions."
  vpc_id      = data.terraform_remote_state.data_model.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The data-model security group already accepts ingress from 10.42.0.0/16
# (the VPC CIDR). The bastion lands in 10.42.10.0/24 and is reachable to
# Aurora without any cross-module security-group rule.

resource "aws_instance" "bastion" {
  ami                    = nonsensitive(data.aws_ssm_parameter.al2023_arm64.value)
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.bastion.id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "dda-bastion" }

  lifecycle {
    # Don't recreate the bastion every time AWS publishes a new AL2023 AMI.
    # Re-create deliberately by `terraform taint` if a refresh is wanted.
    ignore_changes = [ami]
  }
}
