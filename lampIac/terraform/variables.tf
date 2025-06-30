# Variables for the main configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "php-lamp-app"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "production"
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = "bkz-001"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0d64bb532e0502c46" # Ubuntu 22.04 LTS for eu-west-1
}

# Auto Scaling Configuration
variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 5
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

# Database Configuration
variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "lamp_app"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "root"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "SecurePassword123!"
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}
