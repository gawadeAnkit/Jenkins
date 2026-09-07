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
    description     = "Allow HTTP traffic from ALB on port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    cidr_blocks     = [data.aws_vpc.default.cidr_block]
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

# 5. ECS Task Definition (Fargate Serverless Multi-Container: Web + Database)
resource "aws_ecs_task_definition" "vprofile_task" {
  family                   = "vprofile-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024" # 1 vCPU
  memory                   = "2048" # 2048 MB (Plenty of headroom for Tomcat + MySQL)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "vprofile-db"
      image     = "mysql:8.0"
      essential = true

      portMappings = [
        {
          containerPort = 3306
          hostPort      = 3306
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "MYSQL_ROOT_PASSWORD"
          value = var.db_password
        },
        {
          name  = "MYSQL_DATABASE"
          value = "accounts"
        },
        {
          name  = "MYSQL_USER"
          value = var.db_username
        },
        {
          name  = "MYSQL_PASSWORD"
          value = var.db_password
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/vprofile-app"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "vprofile-db"
        }
      }
    },
    {
      name      = "vprofile-web"
      image     = "${aws_ecr_repository.vprofile_app.repository_url}:latest"
      essential = true

      dependsOn = [
        {
          containerName = "vprofile-db"
          condition     = "START"
        }
      ]

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
          "awslogs-group"         = "/ecs/vprofile-app"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "vprofile"
        }
      }

      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        },
        {
          name  = "DB_HOST"
          value = "127.0.0.1"
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_NAME"
          value = "accounts"
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "DB_PASSWORD"
          value = var.db_password
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
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 180

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.vprofile_tg.arn
    container_name   = "vprofile-web"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_policy,
    aws_lb_listener.vprofile_listener
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
