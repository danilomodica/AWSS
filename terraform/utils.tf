/* S3 input bucket configurations */
resource "aws_s3_bucket" "AWSSInputFiles" {
  bucket        = "awss-input-files"
  force_destroy = true

  tags = {
    Name        = "Input files bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_accelerate_configuration" "accelerateInputs" {
  bucket = aws_s3_bucket.AWSSInputFiles.bucket
  status = "Enabled"
}

resource "aws_s3_bucket_acl" "aclInputs" {
  bucket = aws_s3_bucket.AWSSInputFiles.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "accessBlockInputs" {
  bucket = aws_s3_bucket.AWSSInputFiles.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_cors_configuration" "corsInputs" {
  bucket = aws_s3_bucket.AWSSInputFiles.bucket

  cors_rule {
    allowed_headers = ["Authorization"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    expose_headers  = [""]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "inputBucketLifecycle" {
  bucket = aws_s3_bucket.AWSSInputFiles.bucket

  rule {
    id = "expiration"

    expiration {
      days = 7
    }

    filter {}

    status = "Enabled"
  }
}

/* S3 results bucket configurations */
resource "aws_s3_bucket" "AWSSResultFiles" {
  bucket        = "awss-result-files"
  force_destroy = true

  tags = {
    Name        = "Result files bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_accelerate_configuration" "accelerateResults" {
  bucket = aws_s3_bucket.AWSSResultFiles.bucket
  status = "Enabled"
}

resource "aws_s3_bucket_acl" "aclResults" {
  bucket = aws_s3_bucket.AWSSResultFiles.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "accessBlockResults" {
  bucket = aws_s3_bucket.AWSSResultFiles.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_cors_configuration" "corsResults" {
  bucket = aws_s3_bucket.AWSSResultFiles.bucket

  cors_rule {
    allowed_headers = ["Authorization"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    expose_headers  = [""]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "resultsBucketLifecycle" {
  bucket = aws_s3_bucket.AWSSResultFiles.bucket

  rule {
    id = "north-pole"

    expiration {
      days = 365
    }

    filter {}

    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

# FIFO queue that contains jobs to be elaborated
resource "aws_sqs_queue" "inputFIFOQueue" {
  name                        = "inputMsgQueue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  sqs_managed_sse_enabled     = true

  receive_wait_time_seconds  = 20
  message_retention_seconds  = 86400
  max_message_size           = 262144
  delay_seconds              = 0
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.inputFIFOQueue_Deadletter.arn
    maxReceiveCount     = 2
  })

  tags = {
    Name        = "Input info queue"
    Environment = "Production"
  }
}

resource "aws_sqs_queue" "inputFIFOQueue_Deadletter" {
  name                        = "inputMsgQueue_DLQ.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  sqs_managed_sse_enabled     = true

  receive_wait_time_seconds  = 20
  message_retention_seconds  = 604800
  max_message_size           = 262144
  delay_seconds              = 0
  visibility_timeout_seconds = 60

  tags = {
    Name        = "Input info DLQ Queue"
    Environment = "Production"
  }
}

resource "aws_sqs_queue_policy" "inputFIFOQueuePolicy" {
  queue_url = aws_sqs_queue.inputFIFOQueue.id

  policy = templatefile("./templates/OwnerStatement.json", { aws_principal = "arn:aws:iam::${data.aws_caller_identity.current.id}:root", action = "SQS:*", resource_arn = "${aws_sqs_queue.inputFIFOQueue.arn}" })

  depends_on = [data.aws_caller_identity.current,
  aws_sqs_queue.inputFIFOQueue]
}

resource "aws_sqs_queue_policy" "inputFIFOQueue_DeadletterPolicy" {
  queue_url = aws_sqs_queue.inputFIFOQueue_Deadletter.id

  policy = templatefile("./templates/OwnerStatement.json", { aws_principal = "arn:aws:iam::${data.aws_caller_identity.current.id}:root", action = "SQS:*", resource_arn = "${aws_sqs_queue.inputFIFOQueue_Deadletter.arn}" })

  depends_on = [data.aws_caller_identity.current,
  aws_sqs_queue.inputFIFOQueue_Deadletter]
}

# Queue with information to send mails about the result of a job execution
resource "aws_sqs_queue" "sendMailQueue" {
  name                    = "sendMailQueue"
  sqs_managed_sse_enabled = true

  receive_wait_time_seconds  = 20
  message_retention_seconds  = 86400
  max_message_size           = 262144
  delay_seconds              = 0
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sendMailQueue_deadLetter.arn
    maxReceiveCount     = 2
  })

  tags = {
    Name        = "Send Mail function queue"
    Environment = "Production"
  }
}

resource "aws_sqs_queue" "sendMailQueue_deadLetter" {
  name                    = "sendMailQueue_DLQ"
  sqs_managed_sse_enabled = true

  receive_wait_time_seconds  = 20
  message_retention_seconds  = 604800
  max_message_size           = 262144
  delay_seconds              = 0
  visibility_timeout_seconds = 60

  tags = {
    Name        = "Send Mail DLQ Queue"
    Environment = "Production"
  }
}

resource "aws_sqs_queue_policy" "sendMailQueuePolicy" {
  queue_url = aws_sqs_queue.sendMailQueue.id

  policy = templatefile("./templates/OwnerStatement.json", { aws_principal = "arn:aws:iam::${data.aws_caller_identity.current.id}:root", action = "SQS:*", resource_arn = "${aws_sqs_queue.sendMailQueue.arn}" })

  depends_on = [data.aws_caller_identity.current,
  aws_sqs_queue.sendMailQueue]
}

resource "aws_sqs_queue_policy" "sendMailQueue_deadLetterPolicy" {
  queue_url = aws_sqs_queue.sendMailQueue_deadLetter.id

  policy = templatefile("./templates/OwnerStatement.json", { aws_principal = "arn:aws:iam::${data.aws_caller_identity.current.id}:root", action = "SQS:*", resource_arn = "${aws_sqs_queue.sendMailQueue_deadLetter.arn}" })

  depends_on = [data.aws_caller_identity.current,
  aws_sqs_queue.sendMailQueue_deadLetter]
}

#Cloudwatch alarms in case too much messages are sent to dlq queue
resource "aws_cloudwatch_metric_alarm" "sendMailDLQ_alarm" {
  alarm_name                = "sendMailDQL_alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "3"
  metric_name               = "ApproximateNumberOfMessagesVisible"
  namespace                 = "AWS/SQS"
  period                    = "900"
  statistic                 = "Maximum"
  threshold                 = "0"
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []
  alarm_description         = "Send an alarm if emails are not sent correctly by lambda sendMail"
  alarm_actions             = [aws_sns_topic.notify.arn]

  dimensions = { QueueName = "${aws_sqs_queue.sendMailQueue_deadLetter.name}" }
}

resource "aws_cloudwatch_metric_alarm" "FifoDLQ_alarm" {
  alarm_name                = "fifoDQL_alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "3"
  metric_name               = "ApproximateNumberOfMessagesVisible"
  namespace                 = "AWS/SQS"
  period                    = "900"
  statistic                 = "Maximum"
  threshold                 = "0"
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []
  alarm_description         = "Send an alarm if messages are not processed by the cluster"
  alarm_actions             = [aws_sns_topic.notify.arn]

  dimensions = { QueueName = "${aws_sqs_queue.inputFIFOQueue_Deadletter.name}" }
}

/* SNS topic to notify in case of critical problems */
resource "aws_sns_topic" "notify" {
  name = "SNS_notify"
}

resource "aws_sns_topic_subscription" "email-target2" {
  topic_arn = aws_sns_topic.notify.arn
  protocol  = "email"
  endpoint  = var.email
}

/* Lambda to get signed URL from S3 bucket to get/put objects */
data "archive_file" "urlSigner" {
  type             = "zip"
  source_file      = "${path.module}/src/urlSigner.py"
  output_file_mode = "0666"
  output_path      = "./zip/urlSigner.zip"
}

resource "aws_lambda_function" "reqS3lambda" {
  description   = "Function that generates signed url to get/put objects into S3 bucket"
  filename      = "zip/urlSigner.zip"
  function_name = "urlSigner"
  role          = aws_iam_role.s3-lambda-role.arn
  handler       = "urlSigner.lambda_handler"

  source_code_hash = data.archive_file.urlSigner.output_base64sha256

  runtime       = "python3.9"
  architectures = ["x86_64"]

  depends_on = [data.archive_file.urlSigner]

  tags = {
    Name        = "Url Signer function "
    Environment = "Production"
  }
}

/* Lambda Permissions */
resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reqS3lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.apigw.id}/*/*"
}

/* Lambda Log groups */
resource "aws_cloudwatch_log_group" "reqS3LambdaLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.reqS3lambda.function_name}"
  retention_in_days = 90

  tags = {
    Application = "Signed url lambda"
    Environment = "Production"
  }
}

resource "aws_lambda_permission" "cloudwatch_reqS3_allow" {
  statement_id  = "cloudwatch_getS3_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.${var.region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.reqS3LambdaLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "reqS3_logfilter" {
  name            = "gets3_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.reqS3LambdaLogGroup.name
  filter_pattern  = "ERROR"
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.cloudwatch_reqS3_allow]
}

#Lambda function written in Python that send a mail wether a job was completed successfully or not
data "archive_file" "sendMailzip" {
  type             = "zip"
  source_file      = "${path.module}/src/sendMail.py"
  output_file_mode = "0666"
  output_path      = "./zip/sendMail.zip"
}

resource "aws_lambda_function" "sendMail" {
  description   = "Function that notify the user about his job execution"
  filename      = "zip/sendMail.zip"
  function_name = "sendMail"
  role          = aws_iam_role.lambdaSQSRole.arn
  handler       = "sendMail.lambda_handler"

  source_code_hash = data.archive_file.sendMailzip.output_base64sha256

  runtime       = "python3.9"
  architectures = ["arm64"]

  environment {
    variables = {
      gmail_mail = var.email
      psw_gmail  = var.gmail
    }
  }

  depends_on = [data.archive_file.sendMailzip]

  tags = {
    Name        = "Send Mail function"
    Environment = "Production"
  }
}

resource "aws_lambda_function_event_invoke_config" "sendMailRetries" {
  function_name                = aws_lambda_function.sendMail.function_name
  maximum_event_age_in_seconds = 1800
  maximum_retry_attempts       = 2
}

#SendMail log group and subscription to Opensearch
resource "aws_cloudwatch_log_group" "sendMailLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.sendMail.function_name}"
  retention_in_days = 90

  tags = {
    Application = "SendMail lambda"
    Environment = "Production"
  }
}

resource "aws_lambda_permission" "cloudwatch_sendMail_allow" {
  statement_id  = "cloudwatch_sendMail_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.${var.region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.sendMailLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "sendMail_logfilter" {
  name            = "sendMail_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.sendMailLogGroup.name
  filter_pattern  = "ERROR"
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.cloudwatch_sendMail_allow]
}

#Trigger SQS to Lambda
resource "aws_lambda_event_source_mapping" "eventSourceMapping" {
  event_source_arn = aws_sqs_queue.sendMailQueue.arn
  enabled          = true
  function_name    = aws_lambda_function.sendMail.arn
  batch_size       = 10
}

#Useful policies and roles to have a working trigger (SQS) for Lambda
resource "aws_iam_role" "lambdaSQSRole" {
  name        = "lambdaSQSRole"
  description = "Lambda role to give sqs polling and logging permission to lambdas"

  assume_role_policy = templatefile("./templates/LambdaRole.json", {})
}

resource "aws_iam_policy" "SQSPollerPolicySendMail" {
  name        = "SendMailPoller"
  description = "Policy to allow polling actions to sendmail lambda"

  policy = templatefile("./templates/SQSPoller.json", { queue_name = "${aws_sqs_queue.sendMailQueue.name}" })
}

resource "aws_iam_policy" "cwlogging" {
  name        = "cwlogging"
  description = "IAM policy for logging to Cloudwatch"
  path        = "/"

  policy = templatefile("./templates/CWLoggingPermission.json", {})
}

resource "aws_iam_role_policy_attachment" "lambdaLogs1" {
  role       = aws_iam_role.lambdaSQSRole.name
  policy_arn = aws_iam_policy.cwlogging.arn
}

resource "aws_iam_role_policy_attachment" "lambdaLogs2" {
  role       = aws_iam_role.lambdaSQSRole.name
  policy_arn = aws_iam_policy.SQSPollerPolicySendMail.arn
}