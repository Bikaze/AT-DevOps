output "high_cpu_alarm_arn" {
  description = "ARN of the high CPU alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "alb_response_time_alarm_arn" {
  description = "ARN of the ALB response time alarm"
  value       = aws_cloudwatch_metric_alarm.alb_response_time.arn
}

output "unhealthy_hosts_alarm_arn" {
  description = "ARN of the unhealthy hosts alarm"
  value       = aws_cloudwatch_metric_alarm.unhealthy_hosts.arn
}
