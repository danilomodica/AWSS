resource "aws_ecs_cluster" "ecs-cluster" {
  name = "ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecr_repository" "myapp" {
  name                 = "myapp"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_ecr_image" "docker" {
  repository_name = "myapp"
  image_tag       = "latest"
}

/* Role for ECS task definition */
resource "aws_iam_role" "ecs-task-exec" {
  name = "ecs-task-execution-role"
  description = "Allows the execution of ECS tasks"

  assume_role_policy = templatefile("./templates/ecsTaskExecution.json", { version = "2008-10-17" })
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment1" {
  role       = aws_iam_role.ecs-task-exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment2" {
  role       = aws_iam_role.ecs-task-exec.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

/* Role to allow ecs to access s3, sqs and ecr */ 
resource "aws_iam_role" "ecs-resources-access" {
  name = "ecs-resources-access"
  description = "Allows ECS tasks to call AWS services on your behalf"

  assume_role_policy = templatefile("./templates/ecsTaskExecution.json", { version = "2012-10-17" })
}

resource "aws_iam_policy" "ecs-cloudwatch-policy" {
  name        = "CloudWatchLogEcsTask"
  description = "Policy to access logs from ECS"

  policy = templatefile("./templates/CloudWatchLogEcsTask.json", {})
}

resource "aws_iam_role_policy_attachment" "ecs-resources-access-role-policy-attachment1" {
  role       = aws_iam_role.ecs-resources-access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs-resources-access-role-policy-attachment2" {
  role       = aws_iam_role.ecs-resources-access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs-resources-access-role-policy-attachment3" {
  role       = aws_iam_role.ecs-resources-access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs-resources-access-role-policy-attachment4" {
  role       = aws_iam_role.ecs-resources-access.name
  policy_arn = aws_iam_policy.ecs-cloudwatch-policy.arn
}

resource "aws_ecs_task_definition" "ecs-task-definition" {
  family = "myapp"
  container_definitions = templatefile("./templates/containerDefinitions.json", { repo = "${aws_ecr_repository.myapp.repository_url}" })
  
  task_role_arn = aws_iam_role.ecs-resources-access.arn
  execution_role_arn = aws_iam_role.ecs-task-exec.arn

  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = 256
  memory = 512

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

/* IAM Role for RunEcsTask Lambda*/
resource "aws_iam_role" "run-ecs-task" {
  name = "runEcsFargateTask-role"
  description = "Allows Fargate to access logs, run tasks and interact with sqs queues"

  assume_role_policy = templatefile("./templates/lambdaRolePolicy.json", {})
}

resource "aws_iam_policy" "ecs-lambda-policy" {
  name        = "ECSLambdaPolicy"
  description = "Policy to access resources from lambda (logs, ecs)"

  policy = templatefile("./templates/ecsLambdaPolicy.json", {
    iam = data.aws_caller_identity.current.account_id
    ecs = aws_iam_role.ecs-task-exec.arn
  })
}

resource "aws_iam_role_policy_attachment" "ecs-lambda-role-policy-attachment1" {
  role       = aws_iam_role.run-ecs-task.name
  policy_arn = aws_iam_policy.ecs-lambda-policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs-lambda-role-policy-attachment2" {
  role       = aws_iam_role.run-ecs-task.name
  policy_arn = aws_iam_policy.SQSPollerPolicy.arn
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
      region = var.region
      cluster = aws_ecs_cluster.ecs-cluster.arn
      task_definition_name = format("%s:%s", aws_ecs_task_definition.ecs-task-definition.family, aws_ecs_task_definition.ecs-task-definition.revision) 
      app_name_override = aws_ecs_task_definition.ecs-task-definition.family
      bucket_in = aws_s3_bucket.AWSSInputFiles.id
      bucket_out = aws_s3_bucket.AWSSResultFiles.id
      queue_url = aws_sqs_queue.sendMailQueue.url
    }
  }

  depends_on = [data.archive_file.runECSzip]

  tags = {
    Name        = "Run ECS task function"
    Environment = "Dev"
  }
}

# Trigger SQS to RunEcs Lambda
resource "aws_lambda_event_source_mapping" "eventSourceMappingECS" {
  event_source_arn = aws_sqs_queue.inputFIFOQueue.arn
  enabled          = true
  function_name    = aws_lambda_function.runEcsTask.arn
  batch_size       = 10
}