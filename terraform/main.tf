terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.6"
    }
  }

  cloud {
    organization = "AWSS-Cloud"

    workspaces {
      name = "AWSS"
    }
  }
}

variable "ak" {description = "Access key"}
variable "ssk" {description = "Secret key"}
variable "region" {
    description = "Region"
    default = "eu-central-1"
}

variable "upload_directory" {default = "../web-interface/"}
variable "bucket_name" {default = "awss"}
variable "website_url" {default = "awss-cloud.ga"}
variable "email" {default = "awss.unipv@gmail.com"}

variable "acm_certificate_arn" {default = "arn:aws:acm:us-east-1:389487414326:certificate/ad101d25-12a4-423f-bcc1-10f1a0fdfaf0"} #arn certificato SSL/TLS (creato a priori)
variable "certificate_dns_record" {default = "_639b941d3a539ce5f1b80ded0cdf52c6.jhztdrwbnw.acm-validations.aws."}
variable "certificate_cname" {default = "_60bc1a0532bf2a25eeeb788b15dce1f"}

data "aws_caller_identity" "current" {} # to take iam ID

#Credentials to access to OpenSearch dashboard
variable "masterName" {default = "awssCloud"}
variable "masterPass" {default = "awssCC22*"}

output "elasticsearch_credentials" {
  value = [var.masterName, var.masterPass]
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
