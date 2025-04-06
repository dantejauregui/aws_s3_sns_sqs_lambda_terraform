# Provider configuration
provider "aws" {
  region = "eu-central-1" # Change this to your desired region
}

# 1. SNS Topic
resource "aws_sns_topic" "image_upload_topic" {
  name = "image-upload-topic"
}

# 2. SQS Queue
resource "aws_sqs_queue" "image_processing_queue" {
  name = "image-processing-queue"
}

# 3. Lambda IAM Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_sqs_access" {
  name = "LambdaS3SQSAccess"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.image_processing_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "*"
      }
    ]
  })
}

# 4. Lambda Function
resource "aws_lambda_function" "image_processing" {
  filename      = "lambda.zip" # locate zip file next to this terraform code
  function_name = "image_processing_function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 128

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]

  # Note: For the Lambda code, create a separate file and zip it
  # The inline code from CloudFormation should be in a separate file
}

# 5. SNS Topic Policy
resource "aws_sns_topic_policy" "image_upload_topic_policy" {
  arn = aws_sns_topic.image_upload_topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.image_upload_topic.arn
    }]
  })
}

# 6. S3 Bucket with notifications
resource "aws_s3_bucket" "image_upload_bucket" {
  # Bucket name will be auto-generated
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_upload_bucket.id

  topic {
    topic_arn = aws_sns_topic.image_upload_topic.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic_policy.image_upload_topic_policy]
}

# 7. SNS to SQS Subscription
resource "aws_sns_topic_subscription" "sns_to_sqs" {
  topic_arn = aws_sns_topic.image_upload_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.image_processing_queue.arn
}

# 8. SQS Queue Policy
resource "aws_sqs_queue_policy" "image_processing_queue_policy" {
  queue_url = aws_sqs_queue.image_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.image_processing_queue.arn
    }]
  })
}

# 9. Lambda Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_event_mapping" {
  event_source_arn = aws_sqs_queue.image_processing_queue.arn
  function_name    = aws_lambda_function.image_processing.arn
  batch_size       = 1
  enabled          = true

  depends_on = [
    aws_lambda_function.image_processing,
    aws_sqs_queue.image_processing_queue
  ]
}