# ==============================================================================
# Amazon ECS (Fargate) Configuration for VProfile Container Service
# Architecture: Docker Containerized Web App deployed on AWS Fargate
# Author: Ankit Gawade
# ==============================================================================

# 1. ECS Cluster
resource "aws_ecs_cluster" "vprofile_cluster" {
  name = "vprofile-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled" # Keeps CloudWatch within free-tier
  }

  tags = {
    Name    = "vprofile-cluster"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# 2. CloudWatch Log Group for Container Standard Output
resource "aws_cloudwatch_log_group" "ecs_vprofile_logs" {
  name              = "/ecs/vprofile-app"
  retention_in_days = 7

  tags = {
    Name    = "ecs-vprofile-logs"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# 3. IAM Execution Role for ECS Agent (Pulls from ECR & writes logs to CloudWatch)
resource "aws_iam_role" "ecs_execution_role" {
  name = "vprofile-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "vprofile-ecs-execution-role"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. Security Group for ECS Fargate Container Tasks
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "vprofile-ecs-tasks-sg"
  description = "Allow inbound HTTP traffic to VProfile container on port 8080"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "vprofile-ecs-tasks-sg"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# 5. ECS Task Definition (Fargate Serverless)
resource "aws_ecs_task_definition" "vprofile_task" {
  family                   = "vprofile-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "vprofile-web"
      image     = "${aws_ecr_repository.vprofile_app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_vprofile_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "vprofile"
        }
      }

      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
      ]
    }
  ])

  tags = {
    Name    = "vprofile-task-def"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# 6. ECS Service (Deploys and maintains the running container task)
resource "aws_ecs_service" "vprofile_service" {
  name            = "vprofile-service"
  cluster         = aws_ecs_cluster.vprofile_cluster.id
  task_definition = aws_ecs_task_definition.vprofile_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_policy
  ]

  tags = {
    Name    = "vprofile-service"
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = aws_ecs_cluster.vprofile_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS Service"
  value       = aws_ecs_service.vprofile_service.name
}
