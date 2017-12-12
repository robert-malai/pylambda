provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "/516142625866-terraform-state"
    key = "aws-lambda/auto-start-stop.tfstate"
    dynamodb_table = "terraform_locks"
    region = "us-east-1"
  }
}

# --- auto-start-stop provisioning

data "aws_iam_policy_document" "auto_start_stop" {
  "statement" {
    actions = [
      "ec2:Describe*"
    ]

    resources = [ "*" ]
  }

  "statement" {
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances"
    ]

    resources = [
      "arn:aws:ec2:*:531705399537:*"
    ]
  }
}

resource "aws_iam_policy" "auto_start_stop" {
  name = "tf-start-stop-ec2-instances"
  path = "/"
  policy = "${data.aws_iam_policy_document.auto_start_stop.json}"
}

resource "aws_iam_role" "auto_start_stop" {
  name = "tf-lambda-auto-start-stop"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "auto_start_stop_access_rights" {
  policy_arn = "${aws_iam_policy.auto_start_stop.arn}"
  role = "${aws_iam_role.auto_start_stop.name}"
}

resource "aws_iam_role_policy_attachment" "auto_start_stop_execute" {
  role       = "${aws_iam_role.auto_start_stop.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "auto_start_stop" {
  function_name = "auto-start-stop"
  description = "Will start or stop instances based on the 'start-stop:start' tag and the 'start-stop:stop' tag respectively"
  role = "${aws_iam_role.auto_start_stop.arn}"
  runtime = "python3.6"
  filename = "out/auto-start-stop.zip"
  source_code_hash = "${base64sha256(file("out/auto-start-stop.zip"))}"
  handler = "main.handler"
  timeout = "10"
  environment {
    variables {
      TIMEZONE = "America/New_York"
    }
  }
}

resource "aws_cloudwatch_event_rule" "auto_start_stop_event_rule" {
  name = "tf-auto-start-stop-event"
  description = "Fires every ten minutes"
  schedule_expression = "cron(0/10 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "auto_start_stop_event_target" {
  rule = "${aws_cloudwatch_event_rule.auto_start_stop_event_rule.name}"
  target_id = "${aws_lambda_function.auto_start_stop.id}"
  arn = "${aws_lambda_function.auto_start_stop.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_auto_start_stop_function" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.auto_start_stop.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.auto_start_stop_event_rule.arn}"
}