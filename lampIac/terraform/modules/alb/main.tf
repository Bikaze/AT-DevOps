# Application Load Balancer

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = false # Set to true for production

  # Configure ALB attributes
  idle_timeout                     = 60
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 3   # Standard: require 3 consecutive successful checks to mark as healthy
    unhealthy_threshold = 3   # Standard: require 3 consecutive failed checks to mark as unhealthy
    timeout             = 5   # Standard 5 second timeout for health checks
    interval            = 30  # Standard 30 second interval between health checks
    path                = "/" # Default root path served by Apache in the bikaze/lamp container
    matcher             = "200-299"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  # Configure target group attributes
  deregistration_delay = 300 # Standard 300 seconds (5 minutes) for connection draining

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name = "${var.project_name}-targets"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${var.project_name}-listener"
  }
}
