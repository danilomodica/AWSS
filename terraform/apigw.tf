/* S3 Bucket that contains input files to be elaborated */
resource "aws_s3_bucket" "AWSSInputFiles" {
  bucket = "awss-input-files"
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

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

/* S3 Bucket that will contain resulting matched substrings */
resource "aws_s3_bucket" "AWSSResultFiles" {
  bucket = "awss-result-files"
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

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

/* IAM Policies */
resource "aws_iam_policy" "s3-put-policy" {
  name        = "apigateway-to-S3"
  description = "Policy to store objects from S3"

  policy = templatefile("./templates/s3Policy.json", { bucket = "${aws_s3_bucket.AWSSInputFiles.id}", action = "PutObject" })
}

resource "aws_iam_policy" "s3-get-policy" {
  name        = "apigateway-from-S3"
  description = "Policy to get objects from S3"

  policy = templatefile("./templates/s3Policy.json", { bucket = "${aws_s3_bucket.AWSSResultFiles.id}", action = "GetObject" })
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
  description        = "API Gateway to interact with S3 buckets"
  binary_media_types = ["application/octet"]

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_account" "apigw-settings" {
  cloudwatch_role_arn = aws_iam_role.apigateway-role.arn
}

/* API Gateway Resources for the Website */
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
/* TODO */

/* API Gateway Responses */
resource "aws_api_gateway_gateway_response" "cors1" {
  rest_api_id         = aws_api_gateway_rest_api.apigw.id
  response_type       = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
resource "aws_api_gateway_gateway_response" "cors2" {
  rest_api_id         = aws_api_gateway_rest_api.apigw.id
  response_type       = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,PUT'"
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
    aws_api_gateway_method_response.options-response
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
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.apigw.id}/${aws_api_gateway_deployment.apigw-deployment.stage_name}"
  retention_in_days = 0 # never expire
}

/* Output API url in a JSON file */
resource "local_file" "output-json" {
  depends_on = [
    aws_api_gateway_deployment.apigw-deployment
  ]
  content  = "{\"url\": \"${aws_api_gateway_deployment.apigw-deployment.invoke_url}\"}"
  filename = "../web-interface/assets/url.json"
}