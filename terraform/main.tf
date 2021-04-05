# provider block
# ==============================================================
provider "aws" {
    profile = var.profile
    region = var.region
}

# TF backend
# ==============================================================
terraform {
  
    backend "s3" {
      bucket = ""
      key = ""
      region = ""
    }
}

# import default subnets and VPC
# NOTE: these are not created or managed by terraform!
# ==============================================================
resource "aws_default_vpc" "default" {
    tags = {
      name = "default VPC"
    }
}

resource "aws_default_subnet" "default-subnet-az-a" {
    availability_zone = var.az["a"]
    tags = {
      name = "default subnet a"
    }
}

resource "aws_default_subnet" "default-subnet-az-b" {
    availability_zone = var.az["b"]
    tags = {
      name = "default subnet b"
    }
}

resource "aws_default_subnet" "default-subnet-az-c" {
    availability_zone = var.az["c"]
    tags = {
      name = "default subnet c"
    }
}

# Lambda
# ==============================================================
resource "aws_iam_role" "lambda_iam_role" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "shorthand" {
    role = aws_iam_role.lambda_iam_role.arn
    filename = "dummy.zip"
    function_name = "shorthand-handler"
    handler = "lambda/shorthand-handler.handler"
    runtime = "nodejs12.x"
}

resource "aws_lambda_function" "season" {
    role = aws_iam_role.lambda_iam_role.arn
    filename = "dummy.zip"
    function_name = "season-handler"
    handler = "lambda/season-handler.handler"
    runtime = "nodejs12.x"
}

resource "aws_lambda_function" "episode" {
    role = aws_iam_role.lambda_iam_role.arn
    filename = "dummy.zip"
    function_name = "episode-handler"
    handler = "lambda/episode-handler.handler"
    runtime = "nodejs12.x"
}

# APIGW
# ==============================================================
resource "aws_api_gateway_rest_api" "api" {
    name = "${var.name}-backend-api"
}

# prefix all paths with /api/
resource "aws_api_gateway_resource" "base-path" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id  = aws_api_gateway_rest_api.api.root_resource_id
    path_part  = "api"
}

# /shorthand endpoint
resource "aws_api_gateway_resource" "shorthand" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id  = aws_api_gateway_resource.base-path.id
    path_part  = "shorthand"
}

resource "aws_api_gateway_resource" "shorthand-value" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_resource.shorthand.id
    path_part = "{shorthandValue}"    
}

resource "aws_api_gateway_method" "shorthand-get" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.shorthand-value.id
    http_method = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "shorthand-get-integration" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.shorthand-value.id
    http_method = aws_api_gateway_method.shorthand-get.http_method
    
    integration_http_method = "POST"
    type = "AWS_PROXY"
    uri = aws_lambda_function.shorthand.invoke_arn

    depends_on = [ aws_api_gateway_method.shorthand-get ]
}

# /season endpoint
resource "aws_api_gateway_resource" "season" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id  = aws_api_gateway_resource.base-path.id
    path_part  = "season"
}

resource "aws_api_gateway_resource" "season-value" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_resource.season.id
    path_part = "{seasonValue}"
}

resource "aws_api_gateway_method" "season-get" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.season-value.id
    http_method = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "season-get-integration" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.season-value.id
    http_method = aws_api_gateway_method.season-get.http_method
    
    integration_http_method = "POST"
    type = "AWS_PROXY"
    uri = aws_lambda_function.season.invoke_arn

    depends_on = [ aws_api_gateway_method.season-get ]
}

# /episode endpoint
# NOTE episode path starts from seasonValue, not base path
resource "aws_api_gateway_resource" "episode" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id  = aws_api_gateway_resource.season-value.id
    path_part  = "episode"
}

resource "aws_api_gateway_resource" "episode-value" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_resource.episode.id
    path_part = "{episodeValue}"
}

resource "aws_api_gateway_method" "episode-get" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.episode-value.id
    http_method = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "episode-get-integration" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.episode-value.id
    http_method = aws_api_gateway_method.episode-get.http_method
    
    integration_http_method = "POST"
    type = "AWS_PROXY"
    uri = aws_lambda_function.episode.invoke_arn

    depends_on = [ aws_api_gateway_method.episode-get ]
}

# permissions for APIGW to invoke lambda
resource "aws_lambda_permission" "shorthand-lambda-permission" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = "arn:aws:lambda:${var.region}:${var.accountId}:function:${aws_lambda_function.shorthand.function_name}"
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"

    depends_on = [ aws_lambda_function.shorthand ]
}

resource "aws_lambda_permission" "season-lambda-permission" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = "arn:aws:lambda:${var.region}:${var.accountId}:function:${aws_lambda_function.season.function_name}"
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"

    depends_on = [ aws_lambda_function.season ]
}

resource "aws_lambda_permission" "episode-lambda-permission" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = "arn:aws:lambda:${var.region}:${var.accountId}:function:${aws_lambda_function.episode.function_name}"
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"

    depends_on = [ aws_lambda_function.episode ]
}

# APIGateway deployment
resource "aws_api_gateway_deployment" "deployment" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    stage_name = ""

    lifecycle {
      create_before_destroy = true
    }

    depends_on = [
      aws_api_gateway_integration.season-get-integration,
      aws_api_gateway_integration.episode-get-integration,
      aws_api_gateway_integration.shorthand-get-integration
    ]
}

resource "aws_api_gateway_stage" "stage" {
    stage_name = "${var.name}-backend-api"
    rest_api_id = aws_api_gateway_rest_api.api.id
    deployment_id = aws_api_gateway_deployment.deployment.id
}


# DynamoDB
# ==============================================================
resource "aws_dynamodb_table" "scottquotes" {
    name           = "scottquotes"
    billing_mode   = "PROVISIONED"
    read_capacity  = 25
    write_capacity = 25
    hash_key       = "id"

    attribute {
      name = "id"
      type = "S"
    }
}

