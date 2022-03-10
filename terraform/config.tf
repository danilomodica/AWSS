terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "ak" {description = "Access key"}
variable "ssk" {description = "Secret key"}
variable "region" {
    description = "Region"
    default = "eu-west-3"
}
# Configure the AWS Provider
provider "aws" {
  region = var.region
  access_key = var.ak
  secret_key = var.ssk
}