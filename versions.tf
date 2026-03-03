terraform {
  required_version = ">= 1.14.6"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      #version = "~> 6.33.0"
      #version = "~> 6.32.1"
      version = "~> 5.33.0"
    }
  }
}
