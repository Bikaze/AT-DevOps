# Security Groups for the LAMP stack

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access from anywhere"
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access from anywhere"
  }

  # Allow all outbound traffic for health checks and communication with instances
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Security Group
resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-app-"
  description = "Security group for application instances"
  vpc_id      = var.vpc_id

  # HTTP access from ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }

  # HTTP access from anywhere (for debugging - you may want to remove this in production)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access for debugging"
  }

  # SSH access from anywhere (restrict this in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from anywhere"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "Security group for RDS MySQL database"
  vpc_id      = var.vpc_id

  # MySQL access from application instances
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "MySQL access from application instances"
  }

  # No outbound rules needed for RDS
  tags = {
    Name = "${var.project_name}-rds-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
