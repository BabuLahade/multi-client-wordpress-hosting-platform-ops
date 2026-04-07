terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"

      version = "6.35.1"
    }
  }
}
# This is your normal provider keeping your servers in Europe
provider "aws" {
  region = "eu-north-1"
}

# Add this right below it! 
# The "alias" tells Terraform this is a secondary, special-use provider.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}