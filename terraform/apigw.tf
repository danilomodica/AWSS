/* SQS Policy */
resource "aws_iam_policy" "sqs-policy" {
  name        = "apigw-sqsQueue"
  description = "Policy to put messages into SQS"

  policy = templatefile("./templates/SQSApiGWPolicy.json", { sqs = "${aws_sqs_queue.inputFIFOQueue.arn}" })
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

/* S3 IAM Policies for Lambda Role */
resource "aws_iam_policy" "put-s3-lambda-policy" {
  name        = "S3PutLambda"
  description = "Policy to put objects into S3 through lambda"
  policy      = templatefile("./templates/bucketPolicy.json", { bucket = "${aws_s3_bucket.AWSSInputFiles.id}", action = "*" })
}

resource "aws_iam_policy" "get-s3-lambda-policy" {
  name        = "S3GetLambda"
  description = "Policy to get objects from S3 through lambda"
  policy      = templatefile("./templates/bucketPolicy.json", { bucket = "${aws_s3_bucket.AWSSResultFiles.id}", action = "*" })
}

/* Lambda IAM Role */
resource "aws_iam_role" "s3-lambda-role" {
  name = "S3LambdaRole"

  assume_role_policy = templatefile("./templates/lambdaRolePolicy.json", {})
}

/* API Gateway Lambda Policy*/
resource "aws_iam_policy" "apigw-lambda-policy" {
  name = "APIGatewayLambda"

  policy = templatefile("./templates/apiGatewayLambdaPolicy.json", {
    arn_get = "${aws_lambda_function.getS3lambda.arn}",
    arn_put = "${aws_lambda_function.putS3lambda.arn}"
  })
}

/* API Gateway IAM Role */
resource "aws_iam_role" "apigateway-role" {
  name = "APIGatewayS3LambdaRole"

  assume_role_policy = templatefile("./templates/apiGateway.json", {})
}

/* API Gateway Role - Policy attachments */
resource "aws_iam_role_policy_attachment" "role-policy-attach1" {
  role       = aws_iam_role.apigateway-role.name
  policy_arn = aws_iam_policy.apigw-lambda-policy.arn
}
resource "aws_iam_role_policy_attachment" "role-policy-attach2" {
  role       = aws_iam_role.apigateway-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

/* Lambda Role - Policy attachments */
resource "aws_iam_role_policy_attachment" "role-policy-attach3" {
  role       = aws_iam_role.s3-lambda-role.name
  policy_arn = aws_iam_policy.get-s3-lambda-policy.arn
}
resource "aws_iam_role_policy_attachment" "role-policy-attach4" {
  role       = aws_iam_role.s3-lambda-role.name
  policy_arn = aws_iam_policy.put-s3-lambda-policy.arn
}
resource "aws_iam_role_policy_attachment" "role-policy-attach5" {
  role       = aws_iam_role.s3-lambda-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

/* API Gateway Configuration */
resource "aws_api_gateway_rest_api" "apigw" {
  name        = "apiGatewayS3Lambda"
  description = "API Gateway to interact with S3 buckets, through lambdas, and SQS queues"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_account" "apigw-settings" {
  cloudwatch_role_arn = aws_iam_role.apigateway-role.arn
}

resource "aws_api_gateway_request_validator" "req-validator" {
  name                        = "Validate query string parameters and headers"
  rest_api_id                 = aws_api_gateway_rest_api.apigw.id
  validate_request_body       = false
  validate_request_parameters = true
}

/* API Gateway Resources for S3 Lambda */
resource "aws_api_gateway_resource" "bucket-resource" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  parent_id   = aws_api_gateway_rest_api.apigw.root_resource_id
  path_part   = "{bucket}"
}

/* API Gateway S3 Lambda GET Method */
resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.bucket-resource.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.bucket"          = true
    "method.request.querystring.filename" = true
  }

  request_validator_id = aws_api_gateway_request_validator.req-validator.id
}

resource "aws_api_gateway_method_response" "get-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.bucket-resource.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "get" {
  rest_api_id             = aws_api_gateway_rest_api.apigw.id
  resource_id             = aws_api_gateway_resource.bucket-resource.id
  http_method             = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"

  uri         = aws_lambda_function.getS3lambda.invoke_arn
  credentials = aws_iam_role.apigateway-role.arn
}

resource "aws_api_gateway_integration_response" "get-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.bucket-resource.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = aws_api_gateway_method_response.get-response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = "Empty"
  }

  depends_on = [
    aws_api_gateway_method.get,
    aws_api_gateway_method_response.get-response,
    aws_api_gateway_integration.get
  ]
}

/* API Gateway S3 Lambda POST Method */
resource "aws_api_gateway_method" "postS3" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.bucket-resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.bucket"          = true
    "method.request.querystring.filename" = true
  }

  request_validator_id = aws_api_gateway_request_validator.req-validator.id
}

resource "aws_api_gateway_method_response" "postS3-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.bucket-resource.id
  http_method = aws_api_gateway_method.postS3.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "postS3" {
  rest_api_id             = aws_api_gateway_rest_api.apigw.id
  resource_id             = aws_api_gateway_resource.bucket-resource.id
  http_method             = aws_api_gateway_method.postS3.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"

  uri         = aws_lambda_function.putS3lambda.invoke_arn
  credentials = aws_iam_role.apigateway-role.arn
}

resource "aws_api_gateway_integration_response" "postS3-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.bucket-resource.id
  http_method = aws_api_gateway_method.postS3.http_method
  status_code = aws_api_gateway_method_response.postS3-response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = "Empty"
  }

  depends_on = [
    aws_api_gateway_method.postS3,
    aws_api_gateway_method_response.postS3-response,
    aws_api_gateway_integration.postS3
  ]
}

/* API Gateway S3 Lambda OPTIONS Method */
resource "aws_api_gateway_method" "options1" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  resource_id   = aws_api_gateway_resource.bucket-resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options1-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.bucket-resource.id
  http_method = aws_api_gateway_method.options1.http_method
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

resource "aws_api_gateway_integration" "options1" {
  rest_api_id      = aws_api_gateway_rest_api.apigw.id
  resource_id      = aws_api_gateway_resource.bucket-resource.id
  http_method      = aws_api_gateway_method.options1.http_method
  type             = "MOCK"
  content_handling = "CONVERT_TO_TEXT"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "options1-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.bucket-resource.id
  http_method = aws_api_gateway_method.options1.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.options1,
    aws_api_gateway_method_response.options1-response
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
  rest_api_id             = aws_api_gateway_rest_api.apigw.id
  resource_id             = aws_api_gateway_resource.sqs-resource.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS"

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
  rest_api_id      = aws_api_gateway_rest_api.apigw.id
  resource_id      = aws_api_gateway_resource.sqs-resource.id
  http_method      = aws_api_gateway_method.options2.http_method
  type             = "MOCK"
  content_handling = "CONVERT_TO_TEXT"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "options2-response" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.sqs-resource.id
  http_method = aws_api_gateway_method.options2.http_method
  status_code = 200

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
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,PUT,POST'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
resource "aws_api_gateway_gateway_response" "cors2" {
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  response_type = "DEFAULT_5XX"

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
    aws_api_gateway_integration.get,
    aws_api_gateway_integration_response.get-response,
    aws_api_gateway_method.postS3,
    aws_api_gateway_method_response.postS3-response,
    aws_api_gateway_integration.postS3,
    aws_api_gateway_integration_response.postS3-response,
    aws_api_gateway_integration_response.options1-response,
    aws_api_gateway_integration.options1,
    aws_api_gateway_method.options1,
    aws_api_gateway_method_response.options1-response,
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
  statement_id  = "cloudwatch_apigw_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.eu-central-1.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.apigw-log-group.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "apigw_logfilter" {
  name            = "cloudtrail_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.apigw-log-group.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.cloudwatch_apigw_allow]
}

/* Output API url in a JSON file */
resource "local_file" "output-json" {
  depends_on = [
    aws_api_gateway_deployment.apigw-deployment
  ]
  content  = "{\"url\": \"${aws_api_gateway_deployment.apigw-deployment.invoke_url}\"}"
  filename = "../web-interface/assets/url.json"
}