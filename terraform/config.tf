terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.5"
    }
  }
}

variable "ak" {description = "Access key"}
variable "ssk" {description = "Secret key"}
variable "region" {
    description = "Region"
    default = "eu-central-1"
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  access_key = var.ak
  secret_key = var.ssk
}

provider "aws" { #Some services are only available in us-easy-1 (cloudfront/route53)
  alias  = "us-east-1"
  region = "us-east-1"
  access_key = var.ak
  secret_key = var.ssk
}

output "Region" {
  value = var.region
  description = "Distribution region"
}