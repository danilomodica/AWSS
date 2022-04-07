/* S3 Bucket that contains input files to be elaborated */
resource "aws_s3_bucket" "AWSSInputFiles" {
  bucket        = "awss-input-files"
  force_destroy = true

  tags = {
    Name        = "Input files bucket"
    Environment = "Dev"
  }
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

/* S3 Bucket that will contain resulting matched substrings */
resource "aws_s3_bucket" "AWSSResultFiles" {
  bucket        = "awss-result-files"
  force_destroy = true

  tags = {
    Name        = "Result files bucket"
    Environment = "Dev"
  }
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

# FIFO queue that contains jobs to be elaborated
resource "aws_sqs_queue" "inputFIFOQueue" {
  name                        = "inputMsgQueue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  sqs_managed_sse_enabled     = true

  receive_wait_time_seconds  = 10
  message_retention_seconds  = 345600
  max_message_size           = 262144
  delay_seconds              = 0
  visibility_timeout_seconds = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.inputFIFOQueue_Deadletter.arn
    maxReceiveCount     = 100
  })
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = ["${aws_sqs_queue.inputFIFOQueue_Deadletter.arn}"]
  })

  tags = {
    Name        = "Input info queue"
    Environment = "Dev"
  }
}

resource "aws_sqs_queue" "inputFIFOQueue_Deadletter" {
  name                        = "inputMsgQueue_DLQ.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  sqs_managed_sse_enabled     = true

  receive_wait_time_seconds  = 10
  message_retention_seconds  = 345600
  max_message_size           = 262144
  delay_seconds              = 0
  visibility_timeout_seconds = 10

  tags = {
    Name        = "Input info DLQ Queue"
    Environment = "Dev"
  }
}

resource "aws_sqs_queue_policy" "inputFIFOQueuePolicy" {
  queue_url = aws_sqs_queue.inputFIFOQueue.id

  policy = templatefile("./templates/SQSFifoPolicy.json", {
    region     = "${var.region}",
    iam        = "${data.aws_caller_identity.current.account_id}",
    queue_name = "${aws_sqs_queue.inputFIFOQueue.id}",
    role_name  = "${aws_iam_role.apigateway-sqs-role.name}"
  })

  depends_on = [
    data.aws_caller_identity.current,
    aws_iam_role.apigateway-sqs-role
  ]
}

# Queue with information to send mails about the result of a job execution
resource "aws_sqs_queue" "sendMailQueue" {
  name                    = "sendMailQueue"
  sqs_managed_sse_enabled = true

  receive_wait_time_seconds  = 20
  message_retention_seconds  = 86400
  max_message_size           = 24576
  delay_seconds              = 0
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sendMailQueue_deadLetter.arn
    maxReceiveCount     = 100
  })
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = ["${aws_sqs_queue.sendMailQueue_deadLetter.arn}"]
  })

  tags = {
    Name        = "Send Mail function queue"
    Environment = "Dev"
  }
}

resource "aws_sqs_queue" "sendMailQueue_deadLetter" {
  name                    = "sendMailQueue_DLQ"
  sqs_managed_sse_enabled = true

  receive_wait_time_seconds  = 20
  message_retention_seconds  = 86400
  max_message_size           = 24576
  delay_seconds              = 0
  visibility_timeout_seconds = 30

  tags = {
    Name        = "Send Mail DLQ Queue"
    Environment = "Dev"
  }
}

resource "aws_sqs_queue_policy" "sendMailQueuePolicy" {
  queue_url = aws_sqs_queue.sendMailQueue.id

  policy = templatefile("./templates/SQSStandardPolicy.json", {
    region     = "${var.region}",
    iam        = "${data.aws_caller_identity.current.account_id}",
    queue_name = "sendMailQueue"
  })

  depends_on = [data.aws_caller_identity.current]
}

/* Lambda to get signed URL from S3 bucket to get objects */
data "archive_file" "urlSignerGet" {
  type             = "zip"
  source_file      = "${path.module}/lambdaSource/urlSignerGet/lambda_function.py"
  output_file_mode = "0666"
  output_path      = "./zip/urlSignerGet.zip"
}

resource "aws_lambda_function" "getS3lambda" {
  description   = "Function that generates signed url to get objects from S3 bucket"
  filename      = "zip/urlSignerGet.zip"
  function_name = "urlSignerGet"
  role          = aws_iam_role.s3-lambda-role.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.urlSignerGet.output_base64sha256

  runtime       = "python3.9"
  architectures = ["x86_64"]

  depends_on = [data.archive_file.urlSignerGet]

  tags = {
    Name        = "Url Signer Get function "
    Environment = "Dev"
  }
}

/* Lambda to get signed URL from S3 bucket to upload objects */
data "archive_file" "urlSignerPut" {
  type             = "zip"
  source_file      = "${path.module}/lambdaSource/urlSignerPut/lambda_function.py"
  output_file_mode = "0666"
  output_path      = "./zip/urlSignerPut.zip"
}

resource "aws_lambda_function" "putS3lambda" {
  description   = "Function that generates signed url to put objects into S3 bucket"
  filename      = "zip/urlSignerPut.zip"
  function_name = "urlSignerPut"
  role          = aws_iam_role.s3-lambda-role.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.urlSignerPut.output_base64sha256

  runtime       = "python3.9"
  architectures = ["x86_64"]

  depends_on = [data.archive_file.urlSignerPut]

  tags = {
    Name        = "Url Signer Put function "
    Environment = "Dev"
  }
}

/* Lambda Permissions */
resource "aws_lambda_permission" "allow_api1" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.getS3lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.apigw.id}/*/GET/*"
}
resource "aws_lambda_permission" "allow_api2" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.putS3lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.apigw.id}/*/POST/*"
}

/* Lambda Log groups */
resource "aws_cloudwatch_log_group" "getS3LambdaLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.getS3lambda.function_name}"
  retention_in_days = 90

  tags = {
    Application = "Signed get url lambda"
    Environment = "Dev"
  }
}
resource "aws_cloudwatch_log_group" "putS3LambdaLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.putS3lambda.function_name}"
  retention_in_days = 90

  tags = {
    Application = "Signed put url lambda"
    Environment = "Dev"
  }
}

resource "aws_lambda_permission" "cloudwatch_getS3_allow" {
  statement_id  = "cloudwatch_getS3_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.eu-central-1.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.getS3LambdaLogGroup.arn}:*"
}
resource "aws_lambda_permission" "cloudwatch_putS3_allow" {
  statement_id  = "cloudwatch_putS3_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.eu-central-1.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.putS3LambdaLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "getS3_logfilter" {
  name            = "gets3_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.getS3LambdaLogGroup.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.cloudwatch_getS3_allow]
}
resource "aws_cloudwatch_log_subscription_filter" "putS3_logfilter" {
  name            = "puts3_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.putS3LambdaLogGroup.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.cloudwatch_putS3_allow]
}

#Lambda function written in Python that send a mail wether a job was completed successfully or not
data "archive_file" "sendMailzip" {
  type             = "zip"
  source_file      = "${path.module}/lambdaSource/sendMail/lambda_function.py"
  output_file_mode = "0666"
  output_path      = "./zip/sendMail.zip"
}

resource "aws_lambda_function" "sendMail" {
  description   = "Function that notify the user about his job execution"
  filename      = "zip/sendMail.zip"
  function_name = "sendMail"
  role          = aws_iam_role.lambdaSQSRole.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.sendMailzip.output_base64sha256

  runtime       = "python3.9"
  architectures = ["arm64"]

  depends_on = [data.archive_file.sendMailzip]

  tags = {
    Name        = "Send Mail function"
    Environment = "Dev"
  }
}

#SendMail log group and subscription to Opensearch
resource "aws_cloudwatch_log_group" "sendMailLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.sendMail.function_name}"
  retention_in_days = 90

  tags = {
    Application = "SendMail lambda"
    Environment = "Dev"
  }
}

resource "aws_lambda_permission" "cloudwatch_sendMail_allow" {
  statement_id  = "cloudwatch_sendMail_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.eu-central-1.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.sendMailLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "sendMail_logfilter" {
  name            = "sendMail_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.sendMailLogGroup.name
  filter_pattern  = ""
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
resource "aws_iam_policy" "SQSPollerPolicy" {
  name        = "SQSPollerExecutionRole"
  description = "Policy to allow polling actions to lambdas"

  policy = templatefile("./templates/SQSPollerExecutionRole.json", {})
}

resource "aws_iam_policy" "lambdaLogging" {
  name        = "lambdaLogging"
  description = "IAM policy for logging from a lambda"
  path        = "/"

  policy = templatefile("./templates/lambdaLogging.json", {})
}

resource "aws_iam_role" "lambdaSQSRole" {
  name        = "lambdaSQSRole"
  description = "Lambda role to give sqs polling and logging permission to lambdas"

  assume_role_policy = templatefile("./templates/lambdaRolePolicy.json", {})
}

resource "aws_iam_role_policy_attachment" "lambdaLogs1" {
  role       = aws_iam_role.lambdaSQSRole.name
  policy_arn = aws_iam_policy.lambdaLogging.arn
}

resource "aws_iam_role_policy_attachment" "lambdaLogs2" {
  role       = aws_iam_role.lambdaSQSRole.name
  policy_arn = aws_iam_policy.SQSPollerPolicy.arn
}