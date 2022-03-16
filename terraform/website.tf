variable "upload_directory" {default = "../web-interface/"}
variable "bucket_name" {default = "awss"}
variable "website_url" {default = "awss-cloud.ga"}
variable "acm_certificate_arn" {default = "arn:aws:acm:us-east-1:389487414326:certificate/ad101d25-12a4-423f-bcc1-10f1a0fdfaf0"}
locals {mime_types = jsondecode(file("./templates/mime.json"))}

# Bucket configured to host a website
resource "aws_s3_bucket" "www_bucket" {
  bucket = "www.${var.bucket_name}"
  policy = templatefile("templates/s3Policy.json", { bucket = "www.${var.bucket_name}" })

  cors_rule {
    allowed_headers = ["Authorization", "Content-Length"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["https://www.${var.bucket_name}"]
    max_age_seconds = 3000
  }

  website {
    index_document = "index.html"
    #error_document = "404.html"
  }

  tags = {
    Name        = "S3 Website"
    Environment = "Dev"
  }
}

#Upload website files from web-interface folder
resource "aws_s3_bucket_object" "website_files" {
  for_each      = fileset(var.upload_directory, "**/*.*")
  bucket        = aws_s3_bucket.www_bucket.id
  key           = replace(each.value, var.upload_directory, "")
  source        = "${var.upload_directory}${each.value}"
  etag          = filemd5("${var.upload_directory}${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
}

# Cloudfront distribution for main s3 site (only http).
resource "aws_cloudfront_distribution" "www_s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.www_bucket.website_endpoint
    origin_id = "S3-www.${var.bucket_name}"

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled = true
  is_ipv6_enabled = true
  default_root_object = "index.html"

  /*custom_error_response {
    error_caching_min_ttl = 0
    error_code = 404
    response_code = 200
    response_page_path = "/404.html"
  }*/

  aliases = [var.website_url]

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "S3-www.${var.bucket_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
    compress = true
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.acm_certificate_arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "Cloudfront CDN"
    Environment = "Dev"
  }
}

#Adding domain to Route53 redirecting to Cloudfront resources
resource "aws_route53_zone" "route53_zone" {
  name = var.website_url

  tags = {
    Name        = "Route53 Zone"
    Environment = "Dev"
  }
}

resource "aws_route53_record" "cloudfront-www-ipv4" {
  zone_id = aws_route53_zone.route53_zone.zone_id
  name    = var.website_url
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www_s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.www_s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cloudfront-www-ipv6" {
  zone_id = aws_route53_zone.route53_zone.zone_id
  name    = var.website_url
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.www_s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.www_s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.route53_zone.zone_id
  name    = "www.${var.website_url}"
  type    = "CNAME"
  ttl     = "300" #3600
  records = [var.website_url]
}

#For certificate
resource "aws_route53_record" "certificateCNAME" {
  zone_id = aws_route53_zone.route53_zone.zone_id
  name    = "_60bc1a0532bf2a25eeeb788b15dce1f.${var.website_url}"
  type    = "CNAME"
  ttl     = "300" #3600
  records = ["_639b941d3a539ce5f1b80ded0cdf52c6.jhztdrwbnw.acm-validations.aws."]
}

output "Route53_Nameservers" {
  value = aws_route53_zone.route53_zone.name_servers
  description = "Nameserver Route53 to be configured in the domain registrar"
}