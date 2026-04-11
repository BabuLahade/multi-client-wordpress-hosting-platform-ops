resource "aws_cloudwatch_log_group" "wordpress_logs" {
  for_each          = toset(var.ecs_clients) 
  name              = "/ecs/${var.project_name}-${each.key}-wordpress"
  retention_in_days = 7
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name = "${var.project_name}-fargate-cpu-critical"
  comparison_operator = "GreaterThanThreshold"
  metric_name = "CPUUtilization"
  namespace = "AWS/ECS"
  statistic = "Average"

  period = 60
  evaluation_periods = 2
  threshold = 85

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = [var.sns_arn]
# THE ALL-CLEAR: Send another email when the CPU drops back to normal!
  ok_actions = [var.sns_arn]
  alarm_description = "CRITICAL: Fargate Cluster CPU has exceeded 85% for 2 minutes."
}

## alarm for ecs memory  OOM kill
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name = "${var.project_name}-fargate-memory-critical"
  comparison_operator = "GreaterThanThreshold"
  metric_name = "MemoryUtilization"
  namespace = "AWS/ECS"
  statistic = "Average"

  period =60
  evaluation_periods  = 3
  threshold = 85

  dimensions = {
    ClusterName = var.cluster_name
  }
  alarm_actions = [var.sns_arn]
  ok_actions = [var.sns_arn]
  alarm_description = "CRITICAL: fargate memory >85% . container is risk at oom kill"
}

### alarm for RDS storage alrams before full occupy
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name = "${var.project_name}-RDS-storage-low"
  comparison_operator = "LessThanThreshold"
  metric_name = "FreeStorageSpace"
  namespace = "AWS/RDS"
  statistic = "Average"

  period = 300
  evaluation_periods = 1
  ## threshold calculation for storage space mesured in bytes
   # 5 GB = 5 * 1024 * 1024 * 1024 = 5368709120 bytes
  threshold = 5368709120

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  alarm_actions = [var.sns_arn]
  ok_actions = [var.sns_arn]
  alarm_description = "CRITICAL : RDS Database Storage space left < 5GB. "
}
### alarm for 5xx error 
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name = "${var.project_name}-ALB-5xx-spike"
  comparison_operator = "GreaterThanThreshold"
  metric_name = "HTTP_Code_Target_5xx_count"
  namespace = "AWS/ApplicationELB"
  statistic = "Sum"

  period = 60
  evaluation_periods = 1
  threshold = 10 ## alert if we get >10 alb 5XX error

  dimensions = {
    LoadBalancer = var.alb_arn
  }
  alarm_actions = [var.sns_arn]
  ok_actions = [var.sns_arn]
  alarm_description = "CRITICAL: ALB returning 5xx error . application code is failing "
}

### RDS connection Exhaust
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name = "${var.project_name}-RDS-High-Connections"
  comparison_operator = "GreaterThanThreshold"
  metric_name = "DatabaseConnections"
  namespace = "AWS/RDS"
  statistic = "Average"

  period = 60
  evaluation_periods = 2
  threshold = 65 ## means alert at 65 connection i think our instance limit is 85 before it trigger

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  alarm_actions = [var.sns_arn]
  ok_actions = [var.sns_arn]
  alarm_description = "CRITICAL: RDS Database connections are high"
}

#### Alarm for elasticache 
resource "aws_cloudwatch_metric_alarm" "cache_cpu_high" {
  alarm_name = "${var.project_name}-cache-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  metric_name = "EngineCPUUtilization"
  namespace = "AWS/ElastiCache"
  statistic = "Average"

  period = 60
  evaluation_periods = 2  
  threshold = 90

  dimensions = {
    CacheClusterId = var.cache_id
  }
  alarm_actions = [var.sns_arn]
  ok_actions = [var.sns_arn]
  alarm_description = "CRITICAL :ElastiCache Engine CPU is at 90%"
}
# --- ALARM 7: ElastiCache Evictions (Memory Pressure) ---
# This warns us if we need to scale up our cache size because we are out of RAM.
resource "aws_cloudwatch_metric_alarm" "cache_evictions" {
  alarm_name          = "${var.project_name}-Cache-Evictions-Spike"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  statistic           = "Sum"
  period              = 300 # 5 minutes
  evaluation_periods  = 1
  threshold           = 50 # Alert if 50+ items are deleted due to memory pressure

  dimensions = {
    CacheClusterId = var.cache_id
  }

  alarm_actions = [var.sns_arn]
  alarm_description = "WARNING: Cache is full and evicting data. Consider upgrading the ElastiCache node type."
}


#########3 dashboard for those 

resource "aws_cloudwatch_dashboard" "main_dashbpard" {
  dashboard_name = "${var.project_name}-mission-control"

  #  i am using jasonencode to clean and readable
  dashboard_body = jsonencode({
    widgets = [
      # widget 1 : Fargate CPU 
      {
        type = "metric"
        x = 0
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
                ["AWS/ECS" , "CPUUtilization","ClusterName", var.cluster_name ]
          ]
          view = "timeseries"
          stacked = false
          region = "eu-north-1"
          title = "Fargate CPU Utilization"
        }
      } ,
      ## widget 2 FArgate cpu memory
      {
        type = "metric"
        x = 12
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "MemoryUtilization" , "ClusterName", var.cluster_name]
          ]
          view = "timeseries"
          stacked = false
          region = "eu-north-1"
          title = "Fargate Memory Utilization"
        } 
      },
      ### widget 3 RDS connections 
      {
        type = "metric"
        x = 0
        y = 6
        width = 12
        height = 6
        properties = {
          metrics =[
            ["AWS/RDS","DatabaseConnections" , "DBInstanceIdentifier" , var.db_instance_id]
          ]
          view = "timeseries"
          stacked = false 
          region = "eu-north-1"
          title = "RDS Database Connection"
        }
      },
      #### widget 4 ALB 5XX error 
      {
        type = "metric"
        x = 12
        y = 6
        width = 12
        height = 6
        properties ={
          metrics = [
            ["AWS/ApplicationELB","HTTPCode_Target_5XX_count","LoadBalancer",var.alb_arn]
          ]
          view = "timeseries"
          stacked = false
          region = "eu-north-1"
          title = "ALB 5xx Errors (Application Failures)"
          stat = "Sum"
        }
      }


    ]
  })
}