# ==============================================================================
# AWS Application Load Balancer (ALB) Configuration for VProfile Container Service
# Target Architecture: Public HTTP (Port 80) -> Target Group (Port 8080 IP Target)
# Author: Ankit Gawade
# ==============================================================================

# 1. Security Group for Application Load Balancer (Public facing)
resource "aws_security_group" "alb_sg" {
  name        = "vprofile-alb-sg"
  description = "Allow inbound HTTP public traffic to ALB on port 80"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP inbound on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP inbound on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to ECS tasks and VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "vprofile-alb-sg"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# 2. Application Load Balancer
resource "aws_lb" "vprofile_alb" {
  name               = "vprofile-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false

  tags = {
    Name    = "vprofile-alb"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# 3. ALB Target Group (Fargate 'awsvpc' mode requires target_type = 'ip')
resource "aws_lb_target_group" "vprofile_tg" {
  name                 = "vprofile-tg"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.default.id
  target_type          = "ip"
  deregistration_delay = 30 # Speeds up CI/CD rolling updates

  health_check {
    enabled             = true
    path                = "/"
    port                = "8080"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200,302"
  }

  tags = {
    Name    = "vprofile-tg"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# 4. ALB HTTP Listener (Port 80 -> Forward to Target Group)
resource "aws_lb_listener" "vprofile_listener" {
  load_balancer_arn = aws_lb.vprofile_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vprofile_tg.arn
  }

  tags = {
    Name    = "vprofile-alb-listener-80"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# 5. ALB HTTP Listener (Port 8080 -> Forward to Target Group)
resource "aws_lb_listener" "vprofile_listener_8080" {
  load_balancer_arn = aws_lb.vprofile_alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vprofile_tg.arn
  }

  tags = {
    Name    = "vprofile-alb-listener-8080"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}
