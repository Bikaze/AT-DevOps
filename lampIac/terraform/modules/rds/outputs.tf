output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.mysql.port
}

output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.mysql.id
}

output "db_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.mysql.arn
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.mysql.identifier
}
