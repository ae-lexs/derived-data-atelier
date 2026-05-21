terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
  }

  backend "s3" {
    bucket         = "dda-tfstate-795805281797"
    key            = "data-model/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dda-tfstate-lock"
    encrypt        = true
  }
}
