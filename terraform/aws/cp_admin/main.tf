terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# Data sources for infrastructure outputs
data "aws_db_instance" "postgres" {
  db_instance_identifier = var.db_instance_identifier
}

data "aws_secretsmanager_secret" "secret_manager" {
  name = var.secret_manager_name
}

data "aws_s3_bucket" "documents" {
  bucket = var.s3_bucket_name
}

data "aws_ecr_repository" "backend" {
  name = var.ecr_backend_repository_name
}

data "aws_ecr_repository" "frontend" {
  name = var.ecr_frontend_repository_name
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

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
    Name        = "${var.app_name}-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.app_name}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-ecs-tasks-sg"
    Environment = var.environment
  }
}

# Allow ECS tasks to access RDS
resource "aws_security_group_rule" "rds_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = var.db_security_group_id
  description              = "Allow ECS tasks to access RDS"
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  idle_timeout       = 120 # Increase to 120 seconds (or as needed)

  tags = {
    Name        = "${var.app_name}-alb"
    Environment = var.environment
  }
}

# Target Groups
resource "aws_lb_target_group" "backend" {
  name        = "${var.app_name}-backend-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.app_name}-backend-tg"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.app_name}-frontend-tg"
  port        = 8082
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.app_name}-frontend-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name        = "${var.app_name}-cluster"
    Environment = var.environment
  }
}

# IAM Roles
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.app_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.app_name}-ecs-task-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.app_name}-ecs-task-execution-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        data.aws_secretsmanager_secret.secret_manager.arn
      ]
    }]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.app_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.app_name}-ecs-task-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "${var.app_name}-ecs-task-s3"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        data.aws_s3_bucket.documents.arn,
        "${data.aws_s3_bucket.documents.arn}/*"
      ]
    }]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.app_name}/backend"
  retention_in_days = 7

  tags = {
    Name        = "${var.app_name}-backend-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.app_name}/frontend"
  retention_in_days = 7

  tags = {
    Name        = "${var.app_name}-frontend-logs"
    Environment = var.environment
  }
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.app_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "backend"
    image = "${data.aws_ecr_repository.backend.repository_url}:latest"

    portMappings = [{
      containerPort = 9090
      protocol      = "tcp"
    }]

    environment = [
      { name = "DB_HOST", value = data.aws_db_instance.postgres.address },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_NAME", value = data.aws_db_instance.postgres.db_name },
      { name = "DB_USER", value = "postgres" },
      { name = "LLM_BASE_URL", value = var.llm_base_url },
      { name = "USE_S3", value = "true" },
      { name = "S3_BUCKET_NAME", value = data.aws_s3_bucket.documents.id },
      { name = "AWS_REGION", value = var.region }
    ]

    secrets = [
      { name = "DB_PASSWORD", valueFrom = "${data.aws_secretsmanager_secret.secret_manager.arn}:db_password::" },
      { name = "LLM_API_KEY", valueFrom = "${data.aws_secretsmanager_secret.secret_manager.arn}:api_key::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name        = "${var.app_name}-backend-task"
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.app_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "frontend"
    image = "${data.aws_ecr_repository.frontend.repository_url}:latest"

    portMappings = [{
      containerPort = 8082
      protocol      = "tcp"
    }]

    environment = [
      { name = "BACKEND_URL", value = "http://${aws_lb.main.dns_name}" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name        = "${var.app_name}-frontend-task"
    Environment = var.environment
  }
}

# ECS Services
resource "aws_ecs_service" "backend" {
  name            = "${var.app_name}-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 9090
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name        = "${var.app_name}-backend-service"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.app_name}-frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 8082
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name        = "${var.app_name}-frontend-service"
    Environment = var.environment
  }
}
