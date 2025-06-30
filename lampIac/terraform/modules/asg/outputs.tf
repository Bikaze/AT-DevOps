output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "auto_scaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.app.id
}

output "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "cpu_tracking_policy_arn" {
  description = "ARN of the CPU tracking policy"
  value       = aws_autoscaling_policy.cpu_tracking.arn
}
