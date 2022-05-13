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
variable "bucket_name" { default = "awss" }
variable "website_url" { default = "awss-cloud.ga" }
variable "email" { default = "awss.unipv@gmail.com" }

variable "acm_certificate_arn" { default = "arn:aws:acm:us-east-1:389487414326:certificate/72c48e73-7243-4df2-87ca-cb1ad8f82172" } #arn certificato SSL/TLS (creato a priori)
variable "certificate_dns_record1" { default = "_639b941d3a539ce5f1b80ded0cdf52c6.jhztdrwbnw.acm-validations.aws." }
variable "certificate_cname1" { default = "_60bc1a0532bf2a25eeeb788b15dce1ff" }
variable "certificate_dns_record2" { default = "_14c7587d8064c73875ba01c9d4852787.rdnyqppgxp.acm-validations.aws." }
variable "certificate_cname2" { default = "_e3fa9277d49d65725e805971f5f4a099" }

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

provider "aws" { #Some services are only available in us-easy-1 (cloudfront/route53)
  alias      = "us-east-1"
  region     = "us-east-1"
  access_key = var.ak
  secret_key = var.ssk
}

output "Region" {
  value       = var.region
  description = "Distribution region"
}
