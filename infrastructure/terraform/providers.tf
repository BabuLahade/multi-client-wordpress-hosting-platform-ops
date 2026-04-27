terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"

      version = "6.35.1"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}


provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "global"
  region = "us-east-1"
}