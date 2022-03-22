/* SQS Policy */
resource "aws_iam_policy" "sqs-policy" {
  name        = "apigw-sqsQueue"
  description = "Policy to put messages into SQS"

  policy = templatefile("./templates/sqs.json", { sqs = "${aws_sqs_queue.inputFIFOQueue.arn}"})
}

/* SQS IAM Role */
resource "aws_iam_role" "apigateway-sqs-role" {
  name = "apigw-send-msg-sqs"

  assume_role_policy = templatefile("./templates/apiGateway.json", {})
}

/* SQS Role - Policy attachments */
resource "aws_iam_role_policy_attachment" "role-policy-attachment1" {
  role       = aws_iam_role.apigateway-sqs-role.name
  policy_arn = aws_iam_policy.sqs-policy.arn
}
resource "aws_iam_role_policy_attachment" "role-policy-attachment2" {
  role       = aws_iam_role.apigateway-sqs-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# FIFO queue that contains jobs to be elaborated
resource "aws_sqs_queue" "inputFIFOQueue" {
  name                        = "inputMsgQueue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  sqs_managed_sse_enabled     = true
  
  receive_wait_time_seconds = 10
  message_retention_seconds = 345600
  max_message_size          = 262144 
  delay_seconds             = 0
  visibility_timeout_seconds = 10

  tags = {
    Name = "Input info queue"
    Environment = "Dev"
  }
}

# https://github.com/hashicorp/terraform-provider-aws/issues/13980
resource "time_sleep" "wait_60_seconds_1" {
  depends_on = [aws_sqs_queue.inputFIFOQueue]
  create_duration  = "60s"
}

resource "aws_sqs_queue_policy" "inputFIFOQueuePolicy" {
  queue_url = aws_sqs_queue.inputFIFOQueue.id

  policy = templatefile("./templates/SQSFifoPolicy.json", { 
    region = "${var.region}", 
    iam = "${data.aws_caller_identity.current.account_id}",
    queue_name = "inputMsgQueue.fifo", 
    role_name = "${aws_iam_role.apigateway-sqs-role.name}"
  })

  depends_on = [
    time_sleep.wait_60_seconds_1,
    data.aws_caller_identity.current,
    aws_iam_role.apigateway-sqs-role
  ]
}

# Queue with information to send mails about the result of a job execution
resource "aws_sqs_queue" "sendMailQueue" {
  name                        = "sendMailQueue"
  sqs_managed_sse_enabled     = true
  
  receive_wait_time_seconds = 20
  message_retention_seconds = 86400
  max_message_size          = 24576
  delay_seconds             = 0
  visibility_timeout_seconds = 30

  tags = {
    Name = "Send Mail function queue"
    Environment = "Dev"
  }
}

# https://github.com/hashicorp/terraform-provider-aws/issues/13980
resource "time_sleep" "wait_60_seconds_2" {
  depends_on = [aws_sqs_queue.sendMailQueue]
  create_duration  = "60s"
}

resource "aws_sqs_queue_policy" "sendMailQueuePolicy" {
  queue_url = aws_sqs_queue.sendMailQueue.id

  policy = templatefile("./templates/SQSStandardPolicy.json", { 
    region = "${var.region}", 
    iam = "${data.aws_caller_identity.current.account_id}",
    queue_name = "sendMailQueue" 
  })

  depends_on = [
    time_sleep.wait_60_seconds_2,
    data.aws_caller_identity.current
  ]
}

#Lambda function written in Python that send a mail wether a job was completed successfully or not
resource "aws_lambda_function" "sendMail" {
  description = "Function that notify the user about his job execution"
  filename      = "zip/sendMail.zip"
  function_name = "sendMail"
  role          = aws_iam_role.lambdaIAM.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("zip/sendMail.zip")

  runtime = "python3.9"
  architectures = ["arm64"]

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
  statement_id = "cloudwatch_sendMail_allow"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal = "logs.eu-central-1.amazonaws.com"
  source_arn = "${aws_cloudwatch_log_group.sendMailLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "sendMail_logfilter" {
  name            = "sendMail_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.sendMailLogGroup.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [ aws_lambda_permission.cloudwatch_sendMail_allow ]
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
  name = "SQSPollerExecutionRole"

  policy = templatefile("./templates/SQSPollerExecutionRole.json", {})
}

resource "aws_iam_role" "lambdaIAM" {
  name = "lambdaIAM"

  assume_role_policy = templatefile("./templates/LambdaRolePolicy.json", {})
  managed_policy_arns = [aws_iam_policy.SQSPollerPolicy.arn]
}

resource "aws_iam_policy" "lambdaLogging" {
  name        = "lambdaLogging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = templatefile("./templates/SQSLambdaLogging.json", {})
}

resource "aws_iam_role_policy_attachment" "lambdaLogs" {
  role       = aws_iam_role.lambdaIAM.name
  policy_arn = aws_iam_policy.lambdaLogging.arn
}