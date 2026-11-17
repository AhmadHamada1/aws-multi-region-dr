# Failover automation
#
#   Route 53 health check fails
#     -> CloudWatch alarm (us-east-1, where Route 53 metrics live)
#     -> EventBridge rule forwards the alarm event to the secondary Region's bus
#     -> EventBridge rule in the secondary Region invokes the failover Lambda
#     -> Lambda scales the warm-standby ASG to production size and
#        (optionally) promotes the Aurora secondary cluster to writer.
#
# DNS failover itself does not depend on this chain: Route 53 switches the
# record on its own. The Lambda only makes the standby ready for full load.

locals {
  alarm_name = "${local.name}-primary-unhealthy"
}

# ---------------- Notifications ----------------

resource "aws_sns_topic" "alerts_primary" {
  provider = aws.primary
  name     = "${local.name}-dr-alerts"
}

resource "aws_sns_topic" "alerts_secondary" {
  provider = aws.secondary
  name     = "${local.name}-dr-alerts"
}

resource "aws_sns_topic_subscription" "email_primary" {
  count     = var.alert_email == "" ? 0 : 1
  provider  = aws.primary
  topic_arn = aws_sns_topic.alerts_primary.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "email_secondary" {
  count     = var.alert_email == "" ? 0 : 1
  provider  = aws.secondary
  topic_arn = aws_sns_topic.alerts_secondary.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------------- Detection (us-east-1) ----------------

resource "aws_cloudwatch_metric_alarm" "primary_unhealthy" {
  provider            = aws.primary
  alarm_name          = local.alarm_name
  alarm_description   = "Route 53 health check for the primary ALB is failing"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = aws_route53_health_check.primary.id }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts_primary.arn]
  ok_actions          = [aws_sns_topic.alerts_primary.arn]
}

resource "aws_cloudwatch_event_rule" "alarm_primary" {
  provider    = aws.primary
  name        = "${local.name}-forward-dr-alarm"
  description = "Forward the primary-unhealthy alarm to the secondary Region"

  event_pattern = jsonencode({
    source        = ["aws.cloudwatch"]
    "detail-type" = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [local.alarm_name]
      state     = { value = ["ALARM"] }
    }
  })
}

resource "aws_iam_role" "events_forward" {
  provider = aws.primary
  name     = "${local.name}-events-forward"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "events_forward" {
  provider = aws.primary
  name     = "put-events-secondary"
  role     = aws_iam_role.events_forward.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = "arn:aws:events:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:event-bus/default"
    }]
  })
}

resource "aws_cloudwatch_event_target" "to_secondary_bus" {
  provider = aws.primary
  rule     = aws_cloudwatch_event_rule.alarm_primary.name
  arn      = "arn:aws:events:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  role_arn = aws_iam_role.events_forward.arn
}

# ---------------- Response (secondary Region) ----------------

resource "aws_cloudwatch_event_rule" "alarm_secondary" {
  provider    = aws.secondary
  name        = "${local.name}-dr-failover"
  description = "Run the failover runbook when the primary Region is unhealthy"

  event_pattern = jsonencode({
    source        = ["aws.cloudwatch"]
    "detail-type" = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [local.alarm_name]
      state     = { value = ["ALARM"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "failover_lambda" {
  provider = aws.secondary
  rule     = aws_cloudwatch_event_rule.alarm_secondary.name
  arn      = aws_lambda_function.failover.arn
}

resource "aws_lambda_permission" "events" {
  provider      = aws.secondary
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarm_secondary.arn
}

data "archive_file" "failover" {
  type        = "zip"
  source_file = "${path.module}/lambda/failover/handler.py"
  output_path = "${path.module}/build/failover.zip"
}

resource "aws_iam_role" "failover_lambda" {
  provider = aws.secondary
  name     = "${local.name}-failover-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "failover_logs" {
  provider   = aws.secondary
  role       = aws_iam_role.failover_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "failover_lambda" {
  provider = aws.secondary
  name     = "failover-actions"
  role     = aws_iam_role.failover_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["autoscaling:UpdateAutoScalingGroup"]
        Resource = module.secondary.asg_arn
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:DescribeAutoScalingGroups", "rds:DescribeGlobalClusters"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["rds:FailoverGlobalCluster"]
        Resource = [aws_rds_global_cluster.this.arn, aws_rds_cluster.secondary.arn, aws_rds_cluster.primary.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alerts_secondary.arn
      }
    ]
  })
}

resource "aws_lambda_function" "failover" {
  provider         = aws.secondary
  function_name    = "${local.name}-failover"
  role             = aws_iam_role.failover_lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.failover.output_path
  source_code_hash = data.archive_file.failover.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      ASG_NAME              = module.secondary.asg_name
      ASG_MIN               = tostring(var.primary_capacity.min)
      ASG_DESIRED           = tostring(var.primary_capacity.desired)
      ASG_MAX               = tostring(var.primary_capacity.max)
      GLOBAL_CLUSTER_ID     = aws_rds_global_cluster.this.id
      SECONDARY_CLUSTER_ARN = aws_rds_cluster.secondary.arn
      AUTO_PROMOTE_DB       = tostring(var.auto_promote_database)
      SNS_TOPIC_ARN         = aws_sns_topic.alerts_secondary.arn
    }
  }
}
