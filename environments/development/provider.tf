

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  required_version = ">= 0.13"

  backend "s3" {
    bucket = "jks-terraform-state"
    key    = "multiple-environments/development/terraform.tfstate"
    region = "us-west-2"
  }

}
