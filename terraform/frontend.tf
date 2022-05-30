locals { mime_types = jsondecode(file("./templates/mime.json")) }

# WWW S3 BUCKET
resource "aws_s3_bucket" "www_bucket" {
  bucket = "www.${var.service_name}"

  tags = {
    Name        = "S3 Website"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_policy" "www_bucketPolicy" {
  bucket = aws_s3_bucket.www_bucket.id
  policy = templatefile("./templates/OwnerStatement.json", { aws_principal = "${aws_cloudfront_origin_access_identity.CFOAI.iam_arn}", action = "s3:GetObject", resource_arn = "${aws_s3_bucket.www_bucket.arn}/*" })
}

resource "aws_s3_bucket_acl" "www_acl" {
  bucket = aws_s3_bucket.www_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "wwwAccessBlock" {
  bucket = aws_s3_bucket.www_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_website_configuration" "www_bucketWebConfig" {
  bucket = aws_s3_bucket.www_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_cors_configuration" "www_bucketCORS" {
  bucket = aws_s3_bucket.www_bucket.id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Length"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://www.${var.service_name}"]
    max_age_seconds = 3000
  }
}

# Upload website files from web-interface folder
resource "aws_s3_object" "website_files" {
  depends_on = [
    aws_api_gateway_deployment.apigw-deployment,
  local_file.output-json]

  for_each     = fileset(var.interface_directory, "**/*.*")
  bucket       = aws_s3_bucket.www_bucket.id
  key          = replace(each.value, var.interface_directory, "")
  source       = "${var.interface_directory}${each.value}"
  etag         = filemd5("${var.interface_directory}${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
}

resource "aws_s3_object" "website_json_file" { //upload json file with api invoke url, cannot be combined with above resource
  bucket       = aws_s3_bucket.www_bucket.id
  key          = replace(local_file.output-json.filename, var.interface_directory, "")
  source       = local_file.output-json.filename
  etag         = md5(local_file.output-json.content)
  content_type = "application/json"
}

# CLOUDFRONT
resource "aws_cloudfront_origin_access_identity" "CFOAI" {
  comment = "S3 OAI"
}

resource "aws_cloudfront_distribution" "www_s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.www_bucket.bucket_domain_name
    origin_id   = "S3-www.${var.service_name}"

    origin_shield {
      enabled              = true
      origin_shield_region = var.region
    }

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.CFOAI.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 404
    response_code         = 200
    response_page_path    = "/error.html"
  }
  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 403
    response_code         = 200
    response_page_path    = "/error.html"
  }

  aliases = [var.website_url, "www.${var.website_url}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-www.${var.service_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "Cloudfront CDN"
    Environment = "Production"
  }
}

#Route53 resources
resource "aws_route53_record" "cloudfront-www-ipv4" {
  zone_id = var.route_zone_id
  name    = var.website_url
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www_s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.www_s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cloudfront-www-ipv6" {
  zone_id = var.route_zone_id
  name    = var.website_url
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.www_s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.www_s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = var.route_zone_id
  name    = "www.${var.website_url}"
  type    = "CNAME"
  ttl     = "3600"
  records = [var.website_url]
}

resource "aws_route53_health_check" "r53HealthCheck" {
  fqdn              = var.website_url
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"

  tags = {
    Name        = "HTTP Health Check"
    Environment = "Production"
  }
}

#Cloudwatch alarm in case the website is not available
resource "aws_cloudwatch_metric_alarm" "r53_alarm" {
  provider                  = aws.us-east-1
  alarm_name                = "R53-health-check"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "HealthCheckStatus"
  namespace                 = "AWS/Route53"
  period                    = "60"
  statistic                 = "Minimum"
  threshold                 = "1"
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []
  alarm_description         = "Send an alarm if website is down"
  alarm_actions             = [aws_sns_topic.topic.arn]

  dimensions = { HealthCheckId = aws_route53_health_check.r53HealthCheck.id }
}

resource "aws_sns_topic" "topic" {
  provider = aws.us-east-1
  name     = "R53-healthcheck"
}

resource "aws_sns_topic_subscription" "email-target" {
  provider  = aws.us-east-1
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "email"
  endpoint  = var.email
}