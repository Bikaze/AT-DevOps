output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_hosted_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

output "listener_arn" {
  description = "ARN of the ALB listener"
  value       = aws_lb_listener.app.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer for use with CloudWatch and Auto Scaling"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the Target Group for use with CloudWatch and Auto Scaling"
  value       = aws_lb_target_group.app.arn_suffix
}
