provider "aws" {
  region  = "us-east-1"
  profile = "derived-data-atelier"

  default_tags {
    tags = {
      Project   = "derived-data-atelier"
      Module    = "02-apparatus"
      ManagedBy = "terraform"
    }
  }
}
