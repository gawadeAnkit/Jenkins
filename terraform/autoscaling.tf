# ==============================================================================
# AWS Application Auto Scaling Configuration for Amazon ECS Fargate
# Policy: Target Tracking (CPU > 70% | Memory > 80%) with Free-Tier Safe Bounds
# Author: Ankit Gawade
# ==============================================================================

# 1. Scalable Target definition for ECS Service Desired Count
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 3 # Safe upper bound to prevent runaway costs
  min_capacity       = 1 # Baseline active container
  resource_id        = "service/${aws_ecs_cluster.vprofile_cluster.name}/${aws_ecs_service.vprofile_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# 2. CPU Target Tracking Scaling Policy (Target: 70% Average CPU)
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "vprofile-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300 # 5 minutes cooldown before scaling in
    scale_out_cooldown = 60  # 1 minute cooldown before scaling out
  }
}

# 3. Memory Target Tracking Scaling Policy (Target: 80% Average Memory)
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  name               = "vprofile-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300 # 5 minutes cooldown before scaling in
    scale_out_cooldown = 60  # 1 minute cooldown before scaling out
  }
}
