variable "alb_arn" {
  description = "ARN of the Application Load Balancer"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the target group"
  type        = string
}

variable "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  type        = string
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}
