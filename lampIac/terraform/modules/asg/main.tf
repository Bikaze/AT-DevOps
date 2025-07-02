# Launch Template for Auto Scaling Group

# User Data script template
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    db_host     = var.db_endpoint
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
    app_name    = var.project_name
    environment = var.environment
  }))
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix            = "${var.project_name}-template-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  update_default_version = true

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = local.user_data

  network_interfaces {
    associate_public_ip_address = true
    device_index                = 0
    security_groups             = var.security_group_ids
    delete_on_termination       = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-instance"
      Application = var.project_name
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB" # Use ALB health checks for instance health
  health_check_grace_period = 120   # Increased to 120 seconds to allow Docker container to start properly
  termination_policies      = ["OldestInstance", "Default"]
  wait_for_capacity_timeout = "5m"  # Increased to 5 minutes to allow for instance provisioning

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity # Using variable from terraform.tfvars (set to 2)

  default_cooldown = 20             # Reduced to 20 seconds for very quick scaling

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Instead of initial lifecycle hook, create a separate lifecycle hook resource
  # This avoids forcing replacement of the ASG

  # Explicitly attach to target group
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns]
  }

  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 30  # Reduced to 30 seconds for much faster instance provisioning
      checkpoint_delay       = 10  # Adds a 10-second delay between instance replacements
      checkpoint_percentages = [50, 100]  # Check at 50% and 100% completion
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Application"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Lifecycle Hook for instance initialization
resource "aws_autoscaling_lifecycle_hook" "init" {
  name                   = "${var.project_name}-init-hook"
  autoscaling_group_name = aws_autoscaling_group.app.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  heartbeat_timeout      = 30   # Minimum allowed value by AWS
  default_result         = "CONTINUE"
}

# Lifecycle Hook for instance termination
resource "aws_autoscaling_lifecycle_hook" "terminate" {
  name                   = "${var.project_name}-terminate-hook"
  autoscaling_group_name = aws_autoscaling_group.app.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 30   # Minimum allowed value by AWS
  default_result         = "CONTINUE"
}

# Target Tracking Scaling Policy - CPU
resource "aws_autoscaling_policy" "cpu_tracking" {
  name                   = "${var.project_name}-cpu-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 70.0
    disable_scale_in = false
  }
}

# Request Count Target Tracking Policy
resource "aws_autoscaling_policy" "request_count_tracking" {
  name                   = "${var.project_name}-request-count-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_resource_label
    }
    target_value     = 1000.0 # Average requests per instance
    disable_scale_in = false
  }
}

# Step Scaling Policy for emergency scaling
resource "aws_autoscaling_policy" "scale_up" {
  name                    = "${var.project_name}-scale-up"
  policy_type             = "StepScaling"
  adjustment_type         = "ChangeInCapacity"
  autoscaling_group_name  = aws_autoscaling_group.app.name
  metric_aggregation_type = "Average"

  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = 10
  }

  step_adjustment {
    scaling_adjustment          = 2
    metric_interval_lower_bound = 10
  }
}
