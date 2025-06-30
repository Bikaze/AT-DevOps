# CloudWatch Alarms for monitoring

# High CPU Alarm for emergency scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [var.scale_up_policy_arn]

  dimensions = {
    AutoScalingGroupName = var.auto_scaling_group_name
  }

  tags = {
    Name = "${var.project_name}-high-cpu-alarm"
  }
}

# ALB Target Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.project_name}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2.0"
  alarm_description   = "This metric monitors ALB response time"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = regex("app/(.+)", var.alb_arn)[0]
  }

  tags = {
    Name = "${var.project_name}-alb-response-time-alarm"
  }
}

# ALB Unhealthy Host Count Alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy hosts"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = regex("targetgroup/(.+)", var.target_group_arn)[0]
    LoadBalancer = regex("app/(.+)", var.alb_arn)[0]
  }

  tags = {
    Name = "${var.project_name}-unhealthy-hosts-alarm"
  }
}

# HTTP 5xx Error Alarm
resource "aws_cloudwatch_metric_alarm" "http_5xx_errors" {
  alarm_name          = "${var.project_name}-http-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10" # Alert if more than 10 5xx errors in 1 minute
  alarm_description   = "This metric monitors HTTP 5xx error responses from targets"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = regex("targetgroup/(.+)", var.target_group_arn)[0]
    LoadBalancer = regex("app/(.+)", var.alb_arn)[0]
  }

  tags = {
    Name = "${var.project_name}-http-5xx-errors-alarm"
  }
}
