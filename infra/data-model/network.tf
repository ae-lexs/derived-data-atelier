resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "dda-vpc" }
}

# Single AZ — see § IV. If you switch to multi-AZ later, declare a second subnet.
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.42.1.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "dda-private-a" }
}

resource "aws_subnet" "private_b" {
  # Aurora requires a DB subnet group with subnets in at least 2 AZs even for
  # single-AZ deployments. This second subnet stays empty (no instance lives in it)
  # until/unless we promote to multi-AZ. Cost: $0.
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.42.2.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "dda-private-b" }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "dda-aurora"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_security_group" "aurora" {
  name        = "dda-aurora"
  description = "Aurora ingress from inside the VPC only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}

# VPC endpoints — no NAT Gateway, saves ~$32/month per AZ.
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id]
  security_group_ids  = [aws_security_group.aurora.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id]
  security_group_ids  = [aws_security_group.aurora.id]
  private_dns_enabled = true
}
