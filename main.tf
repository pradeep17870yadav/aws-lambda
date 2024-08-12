terraform {

   backend "s3" {
    bucket         = "terraform-aws-lambda-state-file"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

resource "random_pet" "lambda_bucket_name" {
  prefix = "sg-terraform-demo"
  length = 1
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id  
  force_destroy = true
}


data "archive_file" "lambda_sg_demo" {
  type = "zip"

  source_dir  = "${path.module}/sg-demo"
  output_path = "${path.module}/sg-demo.zip"
}

resource "aws_s3_object" "lambda_sg_demo" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "sg-demo.zip"
  source = data.archive_file.lambda_sg_demo.output_path

  etag = filemd5(data.archive_file.lambda_sg_demo.output_path)
}

resource "aws_lambda_function" "sg_demo" {
  function_name = "SGDemo"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_sg_demo.key

  runtime = "python3.9"
  handler = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.lambda_sg_demo.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  timeout = 300  # Timeout set to 5 minutes
}

resource "aws_cloudwatch_log_group" "sg_demo" {
  name = "/aws/lambda/${aws_lambda_function.sg_demo.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_cloudwatch_event_rule" "lambda_sg_demo_schedule" {
  name        = "SGDemoSchedule"
  description = "Trigger Lambda function at 5 PM every day"
  schedule_expression = "cron(0 17 * * ? *)"
}


resource "aws_cloudwatch_event_target" "lambda_sg_demo_target" {
  rule      = aws_cloudwatch_event_rule.lambda_sg_demo_schedule.name
  target_id = "SGDemoLambda"
  arn       = aws_lambda_function.sg_demo.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_lambda" {
  statement_id  = "AllowCloudWatchToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sg_demo.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_sg_demo_schedule.arn
}
