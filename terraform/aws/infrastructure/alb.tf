# Public Application Load Balancer (for frontend)
resource "aws_lb" "gen_alb" {
  name               = "${var.app_name}-gen-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.gen_alb.id]

  idle_timeout       = 120 # Increase to 120 seconds (or as needed)

  tags = {
    Name        = "${var.app_name}-gen-alb"
    Environment = var.environment
  }
}

# Internal Application Load Balancer (for backend - private)
resource "aws_lb" "gen_internal_alb" {
  name               = "${var.app_name}-gen-internal-alb"
  internal           = true  # Internal ALB - only accessible within VPC
  load_balancer_type = "application"
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_groups    = [aws_security_group.gen_internal_alb.id]

  idle_timeout       = 120

  tags = {
    Name        = "${var.app_name}-gen-internal-alb"
    Environment = var.environment
  }
}

# Security Groups
resource "aws_security_group" "gen_alb" {
  name        = "${var.app_name}-gen-alb-sg"
  description = "Security group for Public Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-gen-alb-sg"
    Environment = var.environment
  }
}

# Security Group for Internal ALB (backend)
resource "aws_security_group" "gen_internal_alb" {
  name        = "${var.app_name}-gen-internal-alb-sg"
  description = "Security group for Internal Application Load Balancer (backend)"
  vpc_id      = aws_vpc.main.id

  # Allow traffic from frontend ECS tasks only
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]  # Only allow VPC traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-gen-internal-alb-sg"
    Environment = var.environment
  }
}
