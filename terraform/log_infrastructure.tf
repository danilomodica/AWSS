#Credentials to access to OpenSearch dashboard
variable "masterName" {default = "awssCloud"}
variable "masterPass" {default = "awssCC22*"}

output "elasticsearch_credentials" {
  value = [var.masterName, var.masterPass]
}

resource "aws_elasticsearch_domain" "AWSSElasticsearch" {
  domain_name           = "awss-logs"
  elasticsearch_version = "OpenSearch_1.1"

  #Temporary, it will be substituted by a cluster in different AZ
  cluster_config {
    instance_type = "t3.small.elasticsearch"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10 #Compute the right size depending on the expected log traffic
    volume_type = "gp2"
  }

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name = var.masterName
      master_user_password = var.masterPass
    }
  }

    access_policies = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:eu-central-1:389487414326:domain/awss-logs/*"
    }
  ]
}
  CONFIG

  tags = {
    Name = "Elasticsearch AWSS Domain"
    Environment = "Dev"
  }
}

output "elasticsearch_KibanaURL" {
  value = aws_elasticsearch_domain.AWSSElasticsearch.kibana_endpoint
}

#Lambda that streams log data to opensearch (it is the standard one but uses env variable to point the correct kibana endpoint)
data "archive_file" "cwl2lambdaZip" {
  type             = "zip"
  source_file      = "${path.module}/lambdaSource/cwl2lambda/index.js"
  output_file_mode = "0666"
  output_path      = "./zip/cwl2lambda.zip"
}

resource "aws_lambda_function" "cwl_stream_lambda" {
  description = "Function used to stream log groups to Opensearch cluster"
  filename         = "zip/cwl2lambda.zip"
  function_name    = "LogsToElasticsearch"
  role             = aws_iam_role.lambda_elasticsearch_execution_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.cwl2lambdaZip.output_base64sha256
  runtime          = "nodejs14.x"

  environment {
    variables = {
      es_endpoint = aws_elasticsearch_domain.AWSSElasticsearch.endpoint
    }
  }

  depends_on = [data.archive_file.cwl2lambdaZip]

  tags = {
    Name = "Cloudwatch to Opensearch lambda function"
    Environment = "Dev"
  }
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
    Name = "CloudTrail Logging"
    Environment = "Dev"
  }

    cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudTrailLogGroup.arn}:*" # CloudTrail requires the Log Stream wildcard
    cloud_watch_logs_role_arn = aws_iam_role.cloudTrailIAM.arn
}

resource "aws_s3_bucket" "cloudtrail-s3bucket" { #cloudtrail bucket for logs
  bucket        = "cloudtrail-s3bucket-awss"
  force_destroy = true

  tags = {
    Name        = "Cloudtrail bucket logs"
    Environment = "Dev"
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
  statement_id = "cloudwatch_allow"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal = "logs.eu-central-1.amazonaws.com"
  source_arn = "${aws_cloudwatch_log_group.cloudTrailLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "cloudtrail_logfilter" {
  name            = "cloudtrail_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.cloudTrailLogGroup.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [ aws_lambda_permission.cloudwatch_allow ]
}

#Poliecies and roles...
resource "aws_iam_role" "cloudTrailIAM" {
  name = "cloudTrailIAM"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})

  inline_policy {
    name = "CT-Policy"
    policy = templatefile("./templates/CloudTrailLogPolicy.json", {log-group-arn = aws_cloudwatch_log_group.cloudTrailLogGroup.arn})
  }
}

resource "aws_iam_role" "lambda_elasticsearch_execution_role" {
  name = "lambda_elasticsearch_execution_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_elasticsearch_execution_policy" {
  name = "lambda_elasticsearch_execution_policy"
  role = aws_iam_role.lambda_elasticsearch_execution_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "es:ESHttpPost",
      "Resource": "arn:aws:es:*:*:*"
    }
  ]
}
EOF
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_elasticsearch_execution_role.arn
}

resource "aws_s3_bucket_policy" "CTS3BucketPolicy" {
  bucket = aws_s3_bucket.cloudtrail-s3bucket.id
  depends_on = [aws_s3_bucket.cloudtrail-s3bucket]

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck20160318",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::cloudtrail-s3bucket-awss"
        },
        {
            "Sid": "AWSCloudTrailWrite20150319",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::cloudtrail-s3bucket-awss/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
EOF
}