data "aws_caller_identity" "current" {}

########################################
# DEFAULT VPC, SUBNETS AND SECURITY GROUP
########################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}

########################################
# DYNAMODB TABLE
########################################
resource "aws_dynamodb_table" "greetings" {
  name         = "GreetingLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

########################################
# IAM ROLES & POLICIES
########################################

# Greeter Lambda role
resource "aws_iam_role" "greeter_role" {
  name = "greeter-role-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "greeter_policy" {
  role = aws_iam_role.greeter_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.greetings.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# ECS Task role
resource "aws_iam_role" "ecs_task_role" {
  name = "dispatcher-ecs-task-role-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  role = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["sns:Publish"], Effect = "Allow", Resource = "${var.sns_topic_arn}" },
      { Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Effect = "Allow", Resource = "*" }
    ]
  })
}

# Dispatcher Lambda role
resource "aws_iam_role" "dispatcher_role" {
  name = "dispatcher-role-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "dispatcher_policy" {
  role = aws_iam_role.dispatcher_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = [
          "${aws_ecs_task_definition.dispatcher_task.arn}:*",
          aws_ecs_task_definition.dispatcher_task.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.ecs_task_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

########################################
# LAMBDA FUNCTIONS
########################################
data "archive_file" "greeter_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_greeter/handler.py"
  output_path = "${path.module}/lambda_greeter/lambda.zip"
}

resource "aws_lambda_function" "greeter" {
  function_name    = "greeter-lambda"
  role             = aws_iam_role.greeter_role.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.greeter_lambda.output_path
  source_code_hash = data.archive_file.greeter_lambda.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC  = var.sns_topic_arn
      TABLE_NAME = aws_dynamodb_table.greetings.name
      EMAIL      = var.email
      REPO       = var.repo_url
      REGION     = var.region
    }
  }
}

data "archive_file" "dispatcher_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_dispatcher/handler.py"
  output_path = "${path.module}/lambda_dispatcher/lambda.zip"
}

resource "aws_lambda_function" "dispatcher" {
  function_name    = "dispatcher-lambda"
  role             = aws_iam_role.dispatcher_role.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.dispatcher_lambda.output_path
  source_code_hash = data.archive_file.dispatcher_lambda.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC        = var.sns_topic_arn
      EMAIL            = var.email
      REPO             = var.repo_url
      REGION           = var.region
      ECS_CLUSTER_NAME = aws_ecs_cluster.dispatcher_cluster.name
      TASK_DEFINITION  = aws_ecs_task_definition.dispatcher_task.family
      DEFAULT_SUBNETS  = join(",", data.aws_subnets.default_public.ids)
      DEFAULT_SG       = data.aws_security_group.default.id
    }
  }
}

########################################
# ECS CLUSTER + TASK DEFINITION
########################################
resource "aws_ecs_cluster" "dispatcher_cluster" {
  name = "dispatcher-ecs-cluster"
}

resource "aws_ecs_task_definition" "dispatcher_task" {
  family                   = "dispatcher-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "dispatcher-container"
      image     = "amazon/aws-cli:latest"
      essential = true
      command   = ["sh", "-c", "aws sns publish --topic-arn $SNS_TOPIC --message '{\"email\":\"$EMAIL\",\"source\":\"ECS\",\"region\":\"$REGION\",\"repo\":\"$REPO\"}'"]
      environment = [
        { name = "SNS_TOPIC", value = "arn:aws:sns:us-east-1:263274769945:sns-test" },
        { name = "EMAIL", value = var.email },
        { name = "REGION", value = var.region },
        { name = "REPO", value = var.repo_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/dispatcher-task"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

########################################
# API GATEWAY
########################################
resource "aws_apigatewayv2_api" "api" {
  name          = "test-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

########################################
# API GATEWAY AUTHORIZE (Cognito)
########################################
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${var.cognito_pool_id}" // us-east-1 hardcoded but we can improve for example by "cognito_region" variable
  }

  name = "cognito-jwt-authorizer"
}

########################################
# API INTEGRATIONS
########################################
resource "aws_apigatewayv2_integration" "greeter" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.greeter.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "dispatcher" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.dispatcher.invoke_arn
  payload_format_version = "2.0"
}

########################################
# ROUTES WITH COGNITO AUTH
########################################
resource "aws_apigatewayv2_route" "greet" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /greet"
  target             = "integrations/${aws_apigatewayv2_integration.greeter.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "dispatch" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "POST /dispatch"
  target             = "integrations/${aws_apigatewayv2_integration.dispatcher.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

########################################
# LAMBDA PERMISSIONS
########################################
resource "aws_lambda_permission" "api_gateway_greeter" {
  statement_id  = "AllowAPIGatewayInvokeGreeter"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_dispatcher" {
  statement_id  = "AllowAPIGatewayInvokeDispatcher"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatcher.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
