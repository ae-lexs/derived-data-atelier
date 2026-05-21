# Internet Gateway — required so the bastion (via its public IP) can reach
# the SSM service endpoints (com.amazonaws.us-east-1.{ssm, ssmmessages,
# ec2messages}). Cheaper than three Interface VPC Endpoints (~$22/month) and
# IGWs themselves are free.
resource "aws_internet_gateway" "main" {
  vpc_id = data.terraform_remote_state.data_model.outputs.vpc_id

  tags = { Name = "dda-igw" }
}

# Public subnet for the bastion only. 10.42.10.0/24 is non-overlapping with
# the data-model's private subnets (10.42.1.0/24 and 10.42.2.0/24).
resource "aws_subnet" "bastion" {
  vpc_id                  = data.terraform_remote_state.data_model.outputs.vpc_id
  cidr_block              = "10.42.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "dda-public-bastion" }
}

resource "aws_route_table" "public" {
  vpc_id = data.terraform_remote_state.data_model.outputs.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "dda-public" }
}

resource "aws_route_table_association" "bastion" {
  subnet_id      = aws_subnet.bastion.id
  route_table_id = aws_route_table.public.id
}
