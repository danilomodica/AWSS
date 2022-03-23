variable "upload_directory" {default = "../web-interface/"}
variable "bucket_name" {default = "awss"}
variable "website_url" {default = "awss-cloud.ga"}
variable "acm_certificate_arn" {default = "arn:aws:acm:us-east-1:389487414326:certificate/ad101d25-12a4-423f-bcc1-10f1a0fdfaf0"}
locals {mime_types = jsondecode(file("./templates/mime.json"))}

# Bucket configured to host a website
resource "aws_s3_bucket" "www_bucket" {
  bucket = "www.${var.bucket_name}"

  tags = {
    Name        = "S3 Website"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_policy" "www_bucketPolicy" {
  bucket = aws_s3_bucket.www_bucket.id
  policy = templatefile("templates/s3Policy.json", { bucket = "www.${var.bucket_name}", action = "GetObject" })
}

resource "aws_s3_bucket_website_configuration" "www_bucketWebConfig" {
  bucket = aws_s3_bucket.www_bucket.id

  index_document {
    suffix = "index.html"
  }

  /*error_document {
    key = "error.html"
  }*/
}

resource "aws_s3_bucket_cors_configuration" "www_bucketCORS" {
  bucket = aws_s3_bucket.www_bucket.id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Length"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["https://www.${var.bucket_name}"]
    max_age_seconds = 3000
  }
}

# Upload website files from web-interface folder
resource "aws_s3_object" "website_files" {
  depends_on = [
    aws_api_gateway_deployment.apigw-deployment,
    local_file.output-json
  ]

  for_each      = fileset(var.upload_directory, "**/*.*")
  bucket        = aws_s3_bucket.www_bucket.id
  key           = replace(each.value, var.upload_directory, "")
  source        = "${var.upload_directory}${each.value}"
  etag          = filemd5("${var.upload_directory}${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
}

resource "aws_s3_object" "website_json_file" {
  depends_on = [
    aws_api_gateway_deployment.apigw-deployment,
    local_file.output-json
  ]

  bucket           = aws_s3_bucket.www_bucket.id
  key              = replace(local_file.output-json.filename, var.upload_directory, "")
  source           = "${local_file.output-json.filename}"
}

resource "aws_s3_bucket" "CFLogs" {
  bucket = "awss-cloudfront-logs"
  force_destroy = true

  tags = {
    Name        = "CloudFront Logs"
    Environment = "Dev"
  }
}

# Cloudfront distribution
resource "aws_cloudfront_distribution" "www_s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.www_bucket.bucket_domain_name
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

   logging_config {
    include_cookies = false
    prefix = "logs"
    bucket = aws_s3_bucket.CFLogs.bucket_domain_name
  }

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

resource "aws_route53_record" "certificateCNAME" { #For certificate
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

resource "aws_route53_health_check" "r53HealthCheck" {
  fqdn              = var.website_url
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"

  tags = {
    Name = "HTTP Health Check"
    Environment = "Dev"
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
  insufficient_data_actions = []
  alarm_description         = "Send an alarm if website is down"
  alarm_actions             = [aws_sns_topic.topic.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.r53HealthCheck.id
  }
}

#Used to send advice to a predefined email address (to be set)
resource "aws_sns_topic" "topic" {
  name     = "R53-healthcheck"
  provider = aws.us-east-1
}

#Route53 query log group and subscription to Opensearch
resource "aws_cloudwatch_log_group" "aws_route53_cwl" {
  provider = aws.us-east-1

  name              = "/aws/route53/${aws_route53_zone.route53_zone.name}"
  retention_in_days = 90

  tags = {
    Application = "Route53"
    Environment = "Dev"
  }
}

resource "aws_route53_query_log" "r53_querylog" {
  depends_on = [aws_cloudwatch_log_resource_policy.route53-query-logging-policy]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.aws_route53_cwl.arn
  zone_id                  = aws_route53_zone.route53_zone.zone_id
}

resource "aws_lambda_permission" "cloudwatch_r53_allow" {
  statement_id = "cloudwatch_allow_r53"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal = "logs.us-east-1.amazonaws.com"
  source_arn = "${aws_cloudwatch_log_group.aws_route53_cwl.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "r53_logfilter" {
  provider        = aws.us-east-1
  name            = "r53_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.aws_route53_cwl.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [ aws_lambda_permission.cloudwatch_r53_allow ]
}

#Policies
data "aws_iam_policy_document" "route53-query-logging-policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:log-group:/aws/route53/*"]

    principals {
      identifiers = ["route53.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "route53-query-logging-policy" {
  provider = aws.us-east-1

  policy_document = data.aws_iam_policy_document.route53-query-logging-policy.json
  policy_name     = "route53-query-logging-policy"
}