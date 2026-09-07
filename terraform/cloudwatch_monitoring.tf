# ==============================================================================
# AWS CLOUDWATCH MONITORING & OBSERVABILITY INFRASTRUCTURE (100% FREE TIER)
# Target Architecture: Jenkins Controller & SonarQube Server
# Author: Ankit Gawade
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CLOUDWATCH UNIFIED INFRASTRUCTURE DASHBOARD
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "VProfile-Infrastructure-Monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.jenkins_server.id, { "label": "Jenkins Controller", "color": "#d62728" }],
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.sonarqube_server.id, { "label": "SonarQube Server", "color": "#ff7f0e" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "CI/CD Server CPU Utilization (%)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.jenkins_server.id, { "label": "Jenkins Health" }],
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.sonarqube_server.id, { "label": "SonarQube Health" }]
          ]
          period = 300
          stat   = "Maximum"
          region = var.aws_region
          title  = "Status Check Failures (System Health)"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.jenkins_server.id, { "label": "Jenkins Network In" }],
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.sonarqube_server.id, { "label": "SonarQube Network In" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Network Ingress (Bytes)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.jenkins_server.id, { "label": "Jenkins Network Out" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.sonarqube_server.id, { "label": "SonarQube Network Out" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Network Egress (Bytes)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.vprofile_service.name, "ClusterName", aws_ecs_cluster.vprofile_cluster.name, { "label": "ECS CPU (%)", "color": "#1f77b4" }],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", aws_ecs_service.vprofile_service.name, "ClusterName", aws_ecs_cluster.vprofile_cluster.name, { "label": "ECS Memory (%)", "color": "#2ca02c" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Fargate Resource Utilization (%)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.vprofile_alb.arn_suffix, { "label": "Total Requests", "stat": "Sum" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.vprofile_alb.arn_suffix, { "label": "Avg Response Time (s)", "stat": "Average" }]
          ]
          period = 60
          region = var.aws_region
          title  = "Application Load Balancer Traffic & Latency"
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# 2. CLOUDWATCH METRIC ALARMS (Standard Resolution - Free Tier)
# ------------------------------------------------------------------------------

# Alarm: Jenkins High CPU (> 85%)
resource "aws_cloudwatch_metric_alarm" "jenkins_high_cpu" {
  alarm_name          = "vprofile-jenkins-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Alarm when Jenkins server CPU exceeds 85% for 10 minutes"

  dimensions = {
    InstanceId = aws_instance.jenkins_server.id
  }

  tags = {
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# Alarm: Jenkins Health Check Failure
resource "aws_cloudwatch_metric_alarm" "jenkins_health" {
  alarm_name          = "vprofile-jenkins-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alarm when Jenkins controller fails AWS hardware or reachability checks"

  dimensions = {
    InstanceId = aws_instance.jenkins_server.id
  }

  tags = {
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# Alarm: SonarQube High CPU (> 85%)
resource "aws_cloudwatch_metric_alarm" "sonarqube_high_cpu" {
  alarm_name          = "vprofile-sonarqube-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Alarm when SonarQube server CPU exceeds 85% for 10 minutes"

  dimensions = {
    InstanceId = aws_instance.sonarqube_server.id
  }

  tags = {
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# Alarm: SonarQube Health Check Failure
resource "aws_cloudwatch_metric_alarm" "sonarqube_health" {
  alarm_name          = "vprofile-sonarqube-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alarm when SonarQube server fails AWS hardware or reachability checks"

  dimensions = {
    InstanceId = aws_instance.sonarqube_server.id
  }

  tags = {
    Project = "vprofile"
    Author  = "Ankit Gawade"
  }
}

# ------------------------------------------------------------------------------
# 3. OUTPUTS
# ------------------------------------------------------------------------------
output "cloudwatch_dashboard_url" {
  description = "Direct URL to view your CloudWatch Infrastructure Monitoring Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=VProfile-Infrastructure-Monitoring"
}
