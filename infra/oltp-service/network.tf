data "aws_internet_gateway" "main" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.terraform_remote_state.data_model.outputs.vpc_id]
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = data.terraform_remote_state.data_model.outputs.vpc_id
  cidr_block              = "10.42.20.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # Fargate's assignPublicIp=ENABLED is unreliable when this is false

  tags = { Name = "dda-oltp-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = data.terraform_remote_state.data_model.outputs.vpc_id
  cidr_block              = "10.42.21.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = { Name = "dda-oltp-public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = data.terraform_remote_state.data_model.outputs.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.main.id
  }

  tags = { Name = "dda-oltp-public" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
