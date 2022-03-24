/* SQS Policy */
resource "aws_iam_policy" "sqs-policy" {
  name        = "apigw-sqsQueue"
  description = "Policy to put messages into SQS"

  policy = templatefile("./templates/SQSApiGWPolicy.json", { sqs = "${aws_sqs_queue.inputFIFOQueue.arn}"})
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

/* IAM Policies */
resource "aws_iam_policy" "s3-put-policy" {
  name        = "apigateway-to-S3"
  description = "Policy to store objects from S3"

  policy = templatefile("./templates/bucketPolicy.json", { bucket = "${aws_s3_bucket.AWSSInputFiles.id}", action = "PutObject" })
}

resource "aws_iam_policy" "s3-get-policy" {
  name        = "apigateway-from-S3"
  description = "Policy to get objects from S3"

  policy = templatefile("./templates/bucketPolicy.json", { bucket = "${aws_s3_bucket.AWSSResultFiles.id}", action = "GetObject" })
}

/* IAM Role */
resource "aws_iam_role" "apigateway-role" {
  name = "apigateway-to-S3-role"

  assume_role_policy = templatefile("./templates/apiGateway.json", {})
}

/* Role - Policy attachments */
resource "aws_iam_role_policy_attachment" "role-policy-attach1" {
  role       = aws_iam_role.apigateway-role.name
  policy_arn = aws_iam_policy.s3-put-policy.arn
}
resource "aws_iam_role_policy_attachment" "role-policy-attach2" {
  role       = aws_iam_role.apigateway-role.name
  policy_arn = aws_iam_policy.s3-get-policy.arn
}
resource "aws_iam_role_policy_attachment" "role-policy-attach3" {
  role       = aws_iam_role.apigateway-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

/* API Gateway Configuration */
resource "aws_api_gateway_rest_api" "apigw" {
  name               = "apiGatewayS3"
  description        = "API Gateway to interact with S3 buckets and SQS queues"
  binary_media_types = ["application/octet"]

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_account" "apigw-settings" {
  cloudwatch_role_arn = aws_iam_role.apigateway-role.arn
}

/* API Gateway Resources for S3 */
resource "aws_api_gateway_resource" "bucket-resource" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  parent_id   = aws_api_gateway_rest_api.apigw.root_resource_id
  path_part   = "{bucket}"
}

resource "aws_api_gateway_resource" "filename-resource" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  parent_id   = aws_api_gateway_resource.bucket-resource.id
  path_part   = "{filename}"
}

/* API Gateway GET Method */
resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.filename-resource.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.bucket" = true
    "method.request.path.filename" = true
  }
}

resource "aws_api_gateway_method_response" "get-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.filename-resource.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/octet" = "Empty"
  }
}

resource "aws_api_gateway_integration" "get" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.filename-resource.id
  http_method = aws_api_gateway_method.get.http_method
  integration_http_method = "GET"
  type = "AWS"

  uri         = "arn:aws:apigateway:${var.region}:s3:path/{bucket}/{key}"
  credentials = aws_iam_role.apigateway-role.arn

  request_parameters = {
    "integration.request.path.bucket" = "method.request.path.bucket"
    "integration.request.path.key"    = "method.request.path.filename"
  }
}

resource "aws_api_gateway_integration_response" "get-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.filename-resource.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.get,
    aws_api_gateway_method_response.get-response
  ]
}

/* API Gateway PUT Method */
resource "aws_api_gateway_method" "put" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.filename-resource.id
  http_method   = "PUT"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.bucket" = true
    "method.request.path.filename" = true
  }
}

resource "aws_api_gateway_method_response" "put-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.filename-resource.id
  http_method = aws_api_gateway_method.put.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "put" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.filename-resource.id
  http_method = aws_api_gateway_method.put.http_method
  integration_http_method = "PUT"
  type = "AWS"

  uri         = "arn:aws:apigateway:${var.region}:s3:path/{bucket}/{key}"
  credentials = aws_iam_role.apigateway-role.arn

  request_parameters = {
    "integration.request.path.bucket" = "method.request.path.bucket"
    "integration.request.path.key"    = "method.request.path.filename"
  }

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "put-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.filename-resource.id
  http_method = aws_api_gateway_method.put.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.put,
    aws_api_gateway_method_response.put-response
  ]
}

/* API Gateway OPTIONS Method */
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.filename-resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.bucket" = true
    "method.request.path.filename" = true
  }
}

resource "aws_api_gateway_method_response" "options-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.filename-resource.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.filename-resource.id
  http_method = aws_api_gateway_method.options.http_method
  type = "MOCK"
  content_handling = "CONVERT_TO_TEXT"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "options-response" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.filename-resource.id
  http_method   = aws_api_gateway_method.options.http_method
  status_code   = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.options,
    aws_api_gateway_method_response.options-response
  ]
}

/* API Gateway Resources for SQS */
resource "aws_api_gateway_resource" "sqs-resource" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  parent_id   = aws_api_gateway_rest_api.apigw.root_resource_id
  path_part   = "sqs"
}

/* API Gateway SQS POST Method */
resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.sqs-resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "post-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.sqs-resource.id
  http_method = aws_api_gateway_method.post.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.sqs-resource.id
  http_method = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type = "AWS"

  uri         = "arn:aws:apigateway:${var.region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.inputFIFOQueue.name}"
  credentials = aws_iam_role.apigateway-sqs-role.arn

  request_parameters = { "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'" }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body&MessageGroupId=1"
  }
}

resource "aws_api_gateway_integration_response" "post-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.sqs-resource.id
  http_method = aws_api_gateway_method.post.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.post,
    aws_api_gateway_method_response.post-response
  ]
}

/* API SQS Gateway OPTIONS Method */
resource "aws_api_gateway_method" "options2" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.sqs-resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options2-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.sqs-resource.id
  http_method = aws_api_gateway_method.options2.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "options2" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.sqs-resource.id
  http_method = aws_api_gateway_method.options2.http_method
  type = "MOCK"
  content_handling = "CONVERT_TO_TEXT"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "options2-response" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.sqs-resource.id
  http_method   = aws_api_gateway_method.options2.http_method
  status_code   = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.options2,
    aws_api_gateway_method_response.options2-response
  ]
}

/* API Gateway Responses */
resource "aws_api_gateway_gateway_response" "cors1" {
  rest_api_id         = aws_api_gateway_rest_api.apigw.id
  response_type       = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,PUT,POST'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
resource "aws_api_gateway_gateway_response" "cors2" {
  rest_api_id         = aws_api_gateway_rest_api.apigw.id
  response_type       = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,PUT,POST'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

/* API Gateway Deployment */
resource "aws_api_gateway_deployment" "apigw-deployment" {
  depends_on = [
    aws_api_gateway_method.get,
    aws_api_gateway_method_response.get-response,
    aws_api_gateway_integration_response.get-response,
    aws_api_gateway_integration.get,
    aws_api_gateway_method.put,
    aws_api_gateway_method_response.put-response,
    aws_api_gateway_integration_response.put-response,
    aws_api_gateway_integration.put, 
    aws_api_gateway_integration_response.options-response,
    aws_api_gateway_integration.options,
    aws_api_gateway_method.options,
    aws_api_gateway_method_response.options-response,
    aws_api_gateway_method.post,
    aws_api_gateway_method_response.post-response,
    aws_api_gateway_integration_response.post-response,
    aws_api_gateway_integration.post, 
    aws_api_gateway_integration_response.options2-response,
    aws_api_gateway_integration.options2,
    aws_api_gateway_method.options2,
    aws_api_gateway_method_response.options2-response
  ]
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  stage_name  = "dev"

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.apigw.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method_settings" "stage-settings" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  stage_name  = aws_api_gateway_deployment.apigw-deployment.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "ERROR"
    data_trace_enabled = true
  }
}

resource "aws_cloudwatch_log_group" "apigw-log-group" {
  name              = "/aws/apigw/${aws_api_gateway_rest_api.apigw.name}"
  retention_in_days = 90
}

resource "aws_lambda_permission" "cloudwatch_apigw_allow" {
  statement_id = "cloudwatch_apigw_allow"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal = "logs.eu-central-1.amazonaws.com"
  source_arn = "${aws_cloudwatch_log_group.apigw-log-group.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "apigw_logfilter" {
  name            = "cloudtrail_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.apigw-log-group.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [ aws_lambda_permission.cloudwatch_apigw_allow ]
}

/* Output API url in a JSON file */
resource "local_file" "output-json" {
  depends_on = [
    aws_api_gateway_deployment.apigw-deployment
  ]
  content  = "{\"url\": \"${aws_api_gateway_deployment.apigw-deployment.invoke_url}\"}"
  filename = "../web-interface/assets/url.json"
}