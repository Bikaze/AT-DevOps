variable "vpc_id" {
  description = "VPC ID where RDS will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for RDS subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for RDS"
  type        = list(string)
}

variable "db_name" {
  description = "Name of the database"
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

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}
