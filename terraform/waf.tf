# WEB APPLICATION FIREWALL to limit APIGW accesses
resource "aws_wafv2_web_acl" "waf_apigw" {
  name        = "WAF-Apigw"
  description = "WAF for the API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1
  rule {
    name     = "IP-Limiter"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100 # 100 requests from the same IP per 5 minutes
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "IP-Limiter"
      sampled_requests_enabled   = false
    }
  }

  #From here, AWS predefined firewall rules
  # Rule 2
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = false
    }
  }

  # Rule 3
  rule {
    name     = "AWS-AWSManagedRulesAnonymousIpList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = false
    }
  }

  # Rule 4
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = false
    }
  }

  tags = {
    Environment = "Production"
    Name        = "WAF-Apigw"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAF-Apigw"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl_association" "waf_apigw_association" {
  resource_arn = aws_api_gateway_stage.prodStage.arn
  web_acl_arn  = aws_wafv2_web_acl.waf_apigw.arn
}