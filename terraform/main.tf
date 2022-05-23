terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  cloud {
    organization = "AWSS-Cloud"

    workspaces {
      name = "AWSS"
    }
  }
}

variable "ak" { description = "Access key" }
variable "ssk" { description = "Secret key" }
variable "gmail" { description = "Gmail password" }
variable "region" {
  description = "Region"
  default     = "eu-central-1"
}

variable "upload_directory" { default = "../web-interface/" }
variable "service_name" { default = "awss" }
variable "website_url" { default = "awss-cloud.ga" }
variable "email" { default = "awss.unipv@gmail.com" }

variable "acm_certificate_arn" { default = "arn:aws:acm:us-east-1:389487414326:certificate/72c48e73-7243-4df2-87ca-cb1ad8f82172" } #arn certificato SSL/TLS (creato a priori)
variable "route_zone_id" { default = "Z06871683OMTQJ90WZ6D5" }

data "aws_caller_identity" "current" {} # to take iam ID

#Credentials to access to OpenSearch dashboard
variable "masterName" { default = "awssCloud" }
variable "masterPass" { default = "awssCC22*" }

output "OpenSearch_credentials" {
  value = [var.masterName, var.masterPass]
}

# Configure the AWS Provider
provider "aws" {
  region     = var.region
  access_key = var.ak
  secret_key = var.ssk
}

provider "aws" { #Some services are only available in us-east-1 (cloudfront/route53)
  alias      = "us-east-1"
  region     = "us-east-1"
  access_key = var.ak
  secret_key = var.ssk
}

output "region" {
  value       = var.region
  description = "Distribution region"
}
