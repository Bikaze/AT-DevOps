# RDS MySQL Database

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql-db"

  # Engine configuration
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = false # Free tier doesn't support encryption

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false

  # Connection settings
  max_allocated_storage = 100
  apply_immediately     = true

  # Backup configuration
  backup_retention_period = 0 # Free tier: 0 days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Performance and availability
  multi_az                     = false # Free tier doesn't support Multi-AZ
  performance_insights_enabled = false

  # Deletion protection
  deletion_protection = false # Set to true for production
  skip_final_snapshot = true  # Set to false for production

  # Monitoring
  monitoring_interval             = 0 # Free tier doesn't support enhanced monitoring
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  # Parameter group (using default)
  parameter_group_name = "default.mysql8.0"

  tags = {
    Name = "${var.project_name}-mysql-db"
  }
}
