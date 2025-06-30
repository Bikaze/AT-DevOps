# Main Terraform configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources for existing resources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security_groups"

  vpc_id       = data.aws_vpc.default.id
  project_name = var.project_name
}

# IAM Roles Module
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
}

# RDS Database Module
module "rds" {
  source = "./modules/rds"

  vpc_id             = data.aws_vpc.default.id
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [module.security_groups.rds_security_group_id]
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  db_instance_class  = var.db_instance_class
  allocated_storage  = var.allocated_storage
  project_name       = var.project_name
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"

  vpc_id             = data.aws_vpc.default.id
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [module.security_groups.alb_security_group_id]
  project_name       = var.project_name
}

# Auto Scaling Group Module - depends on RDS and ALB
module "asg" {
  source = "./modules/asg"

  # Explicit dependency to ensure proper resource creation order
  depends_on = [
    module.rds,
    module.alb
  ]

  vpc_id                = data.aws_vpc.default.id
  subnet_ids            = data.aws_subnets.default.ids
  security_group_ids    = [module.security_groups.app_security_group_id]
  target_group_arn      = module.alb.target_group_arn
  instance_profile_name = module.iam.instance_profile_name

  # Database configuration
  db_endpoint = module.rds.db_endpoint
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # Instance configuration
  instance_type = var.instance_type
  key_name      = var.key_name
  ami_id        = var.ami_id

  # Scaling configuration
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # ALB resource label for scaling policy
  alb_resource_label = "${module.alb.alb_arn_suffix}/${module.alb.target_group_arn_suffix}"

  project_name = var.project_name
  environment  = var.environment
}

# CloudWatch Alarms Module - depends on ALB and ASG
module "cloudwatch" {
  source = "./modules/cloudwatch"

  # Explicit dependency to ensure proper resource creation order
  depends_on = [
    module.alb,
    module.asg
  ]

  alb_arn                 = module.alb.alb_arn
  target_group_arn        = module.alb.target_group_arn
  auto_scaling_group_name = module.asg.auto_scaling_group_name
  scale_up_policy_arn     = module.asg.scale_up_policy_arn
  project_name            = var.project_name
}
