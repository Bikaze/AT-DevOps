variable "vpc_id" {
  description = "VPC ID where ASG will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ASG"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for instances"
  type        = list(string)
}

variable "target_group_arn" {
  description = "Target group ARN for the ALB"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

# Database configuration
variable "db_endpoint" {
  description = "RDS database endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Instance configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for instances"
  type        = string
}

# Scaling configuration
variable "min_size" {
  description = "Minimum number of instances"
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb_resource_label" {
  description = "Resource label for ALB request count scaling policy"
  type        = string
  default     = ""
}
