# Output values from the infrastructure
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_hosted_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  value       = module.alb.alb_hosted_zone_id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.db_port
}

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.asg.auto_scaling_group_name
}

output "security_group_ids" {
  description = "Security group IDs"
  value = {
    alb_sg = module.security_groups.alb_security_group_id
    app_sg = module.security_groups.app_security_group_id
    rds_sg = module.security_groups.rds_security_group_id
  }
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.alb.alb_dns_name}"
}

output "health_check_url" {
  description = "URL for health check endpoint"
  value       = "http://${module.alb.alb_dns_name}/health.php"
}

output "db_identifier" {
  description = "RDS database identifier"
  value       = module.rds.db_identifier
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = module.alb.target_group_arn
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "asg_name" {
  description = "ASG Name"
  value       = module.asg.auto_scaling_group_name
}

output "key_name" {
  description = "EC2 Key Name"
  value       = var.key_name
}
