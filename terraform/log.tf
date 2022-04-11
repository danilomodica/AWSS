resource "aws_elasticsearch_domain" "AWSSElasticsearch" {
  domain_name           = "awss-logs"
  elasticsearch_version = "OpenSearch_1.2"

  #!!!!quando bisogna andare in production bisogna calcolare i parametri corretti per numero di nodi e spazio + eventualmente Warm and cold data storage + tipo di istanze

  cluster_config {
    /*zone_awareness_enabled = true
    zone_awareness_config {
      availability_zone_count = 3
    }*/

    #dedicated_master_count   = 1 #3
    #dedicated_master_enabled = true
    #dedicated_master_type    = "t3.small.elasticsearch"

    instance_type  = "t3.small.elasticsearch"
    instance_count = 1 #6
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10 #compute the right size depending on the expected log traffic
    volume_type = "gp2"
  }

  auto_tune_options {
    rollback_on_disable = "NO_ROLLBACK"
    desired_state       = "ENABLED"

    maintenance_schedule {
      cron_expression_for_recurrence = "cron(0 9 ? * SUN *)"
      start_at                       = "2022-07-01T01:00:00Z"
      duration {
        value = 3
        unit  = "HOURS"
      }
    }
  }

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.masterName
      master_user_password = var.masterPass
    }
  }

  log_publishing_options {
    enabled                  = false #true
    log_type                 = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.openSearchLogGroup.arn
  }
  log_publishing_options {
    enabled                  = false #true
    log_type                 = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.openSearchLogGroup.arn
  }
  log_publishing_options {
    enabled                  = false #true
    log_type                 = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.openSearchLogGroup.arn
  }
  log_publishing_options {
    enabled                  = false #true
    log_type                 = "AUDIT_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.openSearchLogGroup.arn
  }

  access_policies = templatefile("./templates/openSearchPolicy.json", {})

  provisioner "local-exec" {
    command = "curl -X PUT -u '${var.masterName}:${var.masterPass}' -H 'Content-Type:application/json' '${aws_elasticsearch_domain.AWSSElasticsearch.endpoint}/_plugins/_security/api/rolesmapping/all_access' -d '{\"backend_roles\" : [\"${aws_iam_role.lambda_opensearch_execution_role.arn}\"],\"hosts\" : [],\"users\" : [\"${var.masterName}\",\"${data.aws_caller_identity.current.arn}\"]}'"
  }

  tags = {
    Name        = "OpenSearch AWSS Domain"
    Environment = "Dev"
  }
}

resource "aws_cloudwatch_log_group" "openSearchLogGroup" {
  name = "openSearchLogGroup"

  retention_in_days = 90

  tags = {
    Application = "OpenSearch"
    Environment = "Dev"
  }
}

resource "aws_cloudwatch_log_resource_policy" "OSLogPolicy" {
  policy_name     = "OSLogPolicy"
  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
CONFIG
}

resource "aws_lambda_permission" "opensearch_allow" {
  statement_id  = "opensearch_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.eu-central-1.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.openSearchLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "openSearch_logfilter" {
  name            = "openSearch_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.openSearchLogGroup.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.opensearch_allow]
}

output "OpenSearch_Dashboard" {
  value = "${aws_elasticsearch_domain.AWSSElasticsearch.endpoint}/_dashboards"
}

#Lambda that streams log data to opensearch (it is the standard one but uses env variable to point the correct kibana endpoint)
data "archive_file" "cwl2lambdaZip" {
  type             = "zip"
  source_file      = "${path.module}/src/cwl2lambda.js"
  output_file_mode = "0666"
  output_path      = "./zip/cwl2lambda.zip"
}

resource "aws_lambda_function" "cwl_stream_lambda" {
  description      = "Function used to stream log groups to Opensearch cluster"
  filename         = "zip/cwl2lambda.zip"
  function_name    = "LogsToElasticsearch"
  role             = aws_iam_role.lambda_opensearch_execution_role.arn
  handler          = "cwl2lambda.handler"
  source_code_hash = data.archive_file.cwl2lambdaZip.output_base64sha256
  runtime          = "nodejs14.x"

  environment {
    variables = {
      es_endpoint = aws_elasticsearch_domain.AWSSElasticsearch.endpoint
    }
  }

  depends_on = [data.archive_file.cwl2lambdaZip]

  tags = {
    Name        = "Cloudwatch to Opensearch lambda function"
    Environment = "Dev"
  }
}

#Cloudwatch alarm in case there are errors using logs lambda
resource "aws_cloudwatch_metric_alarm" "lambdaLog_alarm" {
  alarm_name                = "Lambda_logs_alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "3"
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = "3600"
  statistic                 = "Average"
  threshold                 = "3"
  insufficient_data_actions = []
  alarm_description         = "Send an alarm if logs are not streamed correctly to OpenSearch"
  alarm_actions             = [aws_sns_topic.notify.arn]

  dimensions = { FunctionName = "${aws_lambda_function.cwl_stream_lambda.function_name}" }
}

resource "aws_iam_role" "lambda_opensearch_execution_role" {
  name        = "lambda_opensearch_execution_role"
  description = "IAM Role for lambda used to stream to OpenSearch"

  assume_role_policy = templatefile("./templates/lambdaRolePolicy.json", {})
}

resource "aws_iam_policy" "ESHTTPPolicy" {
  name        = "ESHttpPostPolicy"
  description = "Allow to send log data using http post request to opensearch"
  path        = "/"

  policy = templatefile("./templates/ESHttpPolicy.json", {})
}

resource "aws_iam_role_policy_attachment" "OSLogs1" {
  role       = aws_iam_role.lambda_opensearch_execution_role.name
  policy_arn = aws_iam_policy.lambdaLogging.arn
}

resource "aws_iam_role_policy_attachment" "OSLogs2" {
  role       = aws_iam_role.lambda_opensearch_execution_role.name
  policy_arn = aws_iam_policy.ESHTTPPolicy.arn
}

#Cloudtrail to monitor API usage and user activity
resource "aws_cloudtrail" "cloudtrail" {
  name                          = "cloudtrail-logs"
  s3_bucket_name                = aws_s3_bucket.cloudtrail-s3bucket.id
  include_global_service_events = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  tags = {
    Name        = "CloudTrail Logging"
    Environment = "Dev"
  }

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudTrailLogGroup.arn}:*" # CloudTrail requires the Log Stream wildcard
  cloud_watch_logs_role_arn  = aws_iam_role.cloudTrailIAM.arn
}

resource "aws_iam_role" "cloudTrailIAM" {
  name        = "cloudTrailIAM"
  description = "IAM Role for CloudTrail"

  assume_role_policy = templatefile("./templates/CloudTrailRolePolicy.json", {})

  inline_policy {
    name   = "CT-Policy"
    policy = templatefile("./templates/CloudTrailLogPolicy.json", { log-group-arn = aws_cloudwatch_log_group.cloudTrailLogGroup.arn })
  }
}

resource "aws_s3_bucket" "cloudtrail-s3bucket" { #cloudtrail bucket for logs
  bucket        = "cloudtrail-s3bucket-awss"
  force_destroy = true

  tags = {
    Name        = "Cloudtrail bucket logs"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_acl" "aclCT" {
  bucket = aws_s3_bucket.cloudtrail-s3bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "accessBlockCT" {
  bucket = aws_s3_bucket.cloudtrail-s3bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_policy" "CTS3BucketPolicy" {
  bucket = aws_s3_bucket.cloudtrail-s3bucket.id
  policy = templatefile("./templates/CloudTrailBucketPolicy.json", { bucket_name = "${aws_s3_bucket.cloudtrail-s3bucket.id}", iam = "${data.aws_caller_identity.current.account_id}" })

  depends_on = [aws_s3_bucket.cloudtrail-s3bucket]
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudTrailBucketLifecycle" {
  bucket = aws_s3_bucket.cloudtrail-s3bucket.id

  rule {
    id = "expiration"

    expiration {
      days = 90
    }

    filter {}

    status = "Enabled"
  }
}

#Creating the cloudwatch log group that and the subscription to Opensearch
resource "aws_cloudwatch_log_group" "cloudTrailLogGroup" {
  name = "cloudTrailLogGroup"

  retention_in_days = 90

  tags = {
    Application = "Cloudtrail"
    Environment = "Dev"
  }
}

resource "aws_lambda_permission" "cloudwatch_allow" {
  statement_id  = "cloudwatch_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.eu-central-1.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.cloudTrailLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "cloudtrail_logfilter" {
  name            = "cloudtrail_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.cloudTrailLogGroup.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.cloudwatch_allow]
}