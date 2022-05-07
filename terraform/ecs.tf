resource "aws_ecs_cluster" "ecs-cluster" {
  name = "ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecr_repository" "lcs" {
  name                 = "lcs"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  provisioner "local-exec" { //TEMPORARY
    command = <<EOT
      "docker build -t container ../container/"
      "docker login -u AWS -p $(aws ecr get-login-password --region eu-central-1) 389487414326.dkr.ecr.eu-central-1.amazonaws.com"
      "docker tag container 389487414326.dkr.ecr.eu-central-1.amazonaws.com/lcs"
      "docker push 389487414326.dkr.ecr.eu-central-1.amazonaws.com/lcs"
    EOT
  }
}

/* Role for ECS task definition */
resource "aws_iam_role" "ecs-task-exec" {
  name        = "ecs-task-execution-role"
  description = "Allows the execution of ECS tasks"

  assume_role_policy = templatefile("./templates/ECSRole.json", {})
}

resource "aws_iam_policy" "ecr-policy" {
  name        = "ECRPolicy"
  description = ""

  policy = templatefile("./templates/ECRPermissions.json", {}) //cambiare eventualmente risorsa che lo può usare
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment1" {
  role       = aws_iam_role.ecs-task-exec.name
  policy_arn = aws_iam_policy.ecr-policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment2" {
  role       = aws_iam_role.ecs-task-exec.name
  policy_arn = aws_iam_policy.cwlogging.arn
}

/* Role to allow ecs to access s3, sqs and ecr */
resource "aws_iam_role" "ecs-resources-access" {
  name        = "ecs-resources-access"
  description = "Allows ECS tasks to call AWS services on your behalf"

  assume_role_policy = templatefile("./templates/ECSRole.json", {})
}

resource "aws_iam_role_policy_attachment" "ecs-resources-access-role-policy-attachment1" {
  role       = aws_iam_role.ecs-resources-access.name
  policy_arn = aws_iam_policy.ecr-policy.arn //come sopra
}

resource "aws_iam_policy" "ECSbucketPolicy" {
  name        = "ECSBucketPolicy"
  description = ""

  policy = templatefile("templates/ECSS3Access.json", { bucketIn = "${aws_s3_bucket.AWSSInputFiles.id}", bucketOut = "${aws_s3_bucket.AWSSResultFiles.id}" })
}

resource "aws_iam_policy" "ECSSQSPolicy" {
  name        = "ECSSQSPolicy"
  description = ""

  policy = templatefile("templates/SQSSend.json", { queue_name = "${aws_sqs_queue.sendMailQueue.name}" })
}

resource "aws_iam_role_policy_attachment" "ecs-resources-access-role-policy-attachment2" {
  role       = aws_iam_role.ecs-resources-access.name
  policy_arn = aws_iam_policy.ECSbucketPolicy.arn
}

resource "aws_iam_role_policy_attachment" "ecs-resources-access-role-policy-attachment3" {
  role       = aws_iam_role.ecs-resources-access.name
  policy_arn = aws_iam_policy.ECSSQSPolicy.arn
}

resource "aws_iam_role_policy_attachment" "ecs-resources-access-role-policy-attachment4" {
  role       = aws_iam_role.ecs-resources-access.name
  policy_arn = aws_iam_policy.cwlogging.arn
}

resource "aws_ecs_task_definition" "ecs-task-definition" {
  family                = "lcs"
  container_definitions = templatefile("./templates/ContainerConf.json", { name = "${aws_ecr_repository.lcs.name}", repo = "${aws_ecr_repository.lcs.repository_url}", logGroup = "${aws_cloudwatch_log_group.ECSLogGroup.name}" })

  task_role_arn      = aws_iam_role.ecs-resources-access.arn
  execution_role_arn = aws_iam_role.ecs-task-exec.arn

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

/* IAM Role for RunEcsTask Lambda*/
resource "aws_iam_role" "run-ecs-task" {
  name        = "runEcsFargateTask-role"
  description = "Allows Fargate to access logs, run tasks and interact with sqs queues"

  assume_role_policy = templatefile("./templates/LambdaRole.json", {})
}

resource "aws_iam_policy" "ecs-lambda-policy" {
  name        = "ECSLambdaPolicy"
  description = "Policy to access resources from lambda (logs, ecs)"

  policy = templatefile("./templates/ECSLambda.json", {
    iam = data.aws_caller_identity.current.account_id
    ecs = aws_iam_role.ecs-task-exec.arn
  })
}

resource "aws_iam_policy" "SQSPollerPolicyFifo" {
  name        = "ECSPoller"
  description = "Policy to allow fifo queue polling actions to ecs lambda"

  policy = templatefile("./templates/SQSPoller.json", { queue_name = "${aws_sqs_queue.inputFIFOQueue.name}" })
}

resource "aws_iam_policy" "SendtoFifoDLQPolicy" {
  name        = "SendToFifoDLQ"
  description = "Policy to allow sending to fifo dlq from ecs lambda"

  policy = templatefile("./templates/SQSSend.json", { queue_name = "${aws_sqs_queue.inputFIFOQueue_Deadletter.name}" })
}

resource "aws_iam_role_policy_attachment" "ecs-lambda-role-policy-attachment1" {
  role       = aws_iam_role.run-ecs-task.name
  policy_arn = aws_iam_policy.ecs-lambda-policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs-lambda-role-policy-attachment2" {
  role       = aws_iam_role.run-ecs-task.name
  policy_arn = aws_iam_policy.SQSPollerPolicyFifo.arn
}

resource "aws_iam_role_policy_attachment" "ecs-lambda-role-policy-attachment3" {
  role       = aws_iam_role.run-ecs-task.name
  policy_arn = aws_iam_policy.SendtoFifoDLQPolicy.arn
}

# Lambda function written in Python that runs a task into ECS cluster
data "archive_file" "runECSzip" {
  type             = "zip"
  source_file      = "${path.module}/src/runEcsTask.py"
  output_file_mode = "0666"
  output_path      = "./zip/runEcsTask.zip"
}

resource "aws_lambda_function" "runEcsTask" {
  description   = "Function that runs a task into ECS cluster"
  filename      = "zip/runEcsTask.zip"
  function_name = "runEcsTask"
  role          = aws_iam_role.run-ecs-task.arn
  handler       = "runEcsTask.lambda_handler"

  source_code_hash = data.archive_file.runECSzip.output_base64sha256

  runtime       = "python3.9"
  architectures = ["arm64"]

  environment {
    variables = {
      region               = var.region
      cluster              = aws_ecs_cluster.ecs-cluster.arn
      task_definition_name = format("%s:%s", aws_ecs_task_definition.ecs-task-definition.family, aws_ecs_task_definition.ecs-task-definition.revision)
      app_name_override    = aws_ecs_task_definition.ecs-task-definition.family
      bucket_in            = aws_s3_bucket.AWSSInputFiles.id
      bucket_out           = aws_s3_bucket.AWSSResultFiles.id
      queue_url            = aws_sqs_queue.sendMailQueue.url
    }
  }

  depends_on = [data.archive_file.runECSzip]

  tags = {
    Name        = "Run ECS task function"
    Environment = "Dev"
  }
}

resource "aws_cloudwatch_log_group" "runEcsTaskLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.runEcsTask.function_name}"
  retention_in_days = 90

  tags = {
    Application = "runEcsTask lambda"
    Environment = "Dev"
  }
}

resource "aws_lambda_permission" "cloudwatch_runEcsTask_allow" {
  statement_id  = "cloudwatch_runEcsTask_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.${var.region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.runEcsTaskLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "runEcsTask_logfilter" {
  name            = "runEcsTask_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.runEcsTaskLogGroup.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.cloudwatch_runEcsTask_allow]
}

resource "aws_cloudwatch_log_group" "ECSLogGroup" {
  name              = "/aws/ecs/${aws_ecr_repository.lcs.name}"
  retention_in_days = 90

  tags = {
    Application = "ECS Cluster"
    Environment = "Dev"
  }
}

resource "aws_lambda_permission" "cloudwatch_ecs_allow" {
  statement_id  = "cloudwatch_ecs_allow"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cwl_stream_lambda.function_name
  principal     = "logs.${var.region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.ECSLogGroup.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "ecs_logfilter" {
  name            = "ecs_logsubscription"
  log_group_name  = aws_cloudwatch_log_group.ECSLogGroup.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.cwl_stream_lambda.arn

  depends_on = [aws_lambda_permission.cloudwatch_ecs_allow]
}

# Trigger SQS to RunEcs Lambda
resource "aws_lambda_event_source_mapping" "eventSourceMappingECS" {
  event_source_arn = aws_sqs_queue.inputFIFOQueue.arn
  enabled          = true
  function_name    = aws_lambda_function.runEcsTask.arn
  batch_size       = 10
}