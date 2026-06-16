data "terraform_remote_state" "data_model" {
  backend = "s3"

  config = {
    bucket = "dda-tfstate-795805281797"
    key    = "data-model/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "apparatus" {
  backend = "s3"

  config = {
    bucket = "dda-tfstate-795805281797"
    key    = "apparatus/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
