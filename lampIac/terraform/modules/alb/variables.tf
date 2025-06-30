variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for ALB"
  type        = list(string)
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}
