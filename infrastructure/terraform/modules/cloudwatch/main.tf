resource "aws_cloudwatch_log_group" "wordpress_logs" {
  for_each          = toset(var.ecs_clients) 
  name              = "/ecs/${var.project_name}-${each.key}-wordpress"
  retention_in_days = 7
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = toset(var.ecs_clients)
  alarm_name = "${var.project_name}-${each.key}-fargate-cpu-critical"
  comparison_operator = "GreaterThanThreshold"
  metric_name = "CPUUtilization"
  namespace = "AWS/ECS"
  statistic = "Average"

  period = 60
  evaluation_periods = 2
  threshold = 85

  dimensions = {
    ClusterName = var.cluster_name
    # ServiceName = var.service_name[each.key]
    ServiceName = "${var.project_name}-${each.key}-service"
  }

  alarm_actions = [var.sns_critical_arn]
# THE ALL-CLEAR: Send another email when the CPU drops back to normal!
  ok_actions = [var.sns_critical_arn]
  treat_missing_data = "notBreaching"
  alarm_description = "CRITICAL: Fargate Cluster CPU has exceeded 85% for 2 minutes."
}

## alarm for ecs memory  OOM kill
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  for_each = toset(var.ecs_clients)
  alarm_name = "${var.project_name}-${each.key}fargate-memory-critical"
  comparison_operator = "GreaterThanThreshold"
  metric_name = "MemoryUtilization"
  namespace = "AWS/ECS"
  statistic = "Average"

  period =60
  evaluation_periods  = 3
  threshold = 85

  dimensions = {
    ClusterName = var.cluster_name
    # ServiceName = var.service_name[each.key]
    ServiceName = "${var.project_name}-${each.key}-service"
  }
  alarm_actions = [var.sns_critical_arn]
  ok_actions = [var.sns_critical_arn]
  treat_missing_data = "notBreaching"
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
  evaluation_periods = 2
  ## threshold calculation for storage space mesured in bytes
   # 5 GB = 5 * 1024 * 1024 * 1024 = 5368709120 bytes
  threshold = 5368709120

  dimensions = {
    DBInstanceIdentifier = "wordpress-hosting-db-instance"
  }
  alarm_actions = [var.sns_critical_arn]
  ok_actions = [var.sns_critical_arn]
  treat_missing_data = "notBreaching"
  alarm_description = "CRITICAL : RDS Database Storage space left < 5GB. "
}
### alarm for 5xx error 
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  for_each = toset(var.ecs_clients)
  alarm_name = "${var.project_name}-ALB-5xx-spike-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  metric_name = "HTTPCode_Target_5XX_Count"
  namespace = "AWS/ApplicationELB"
  statistic = "Sum"

  period = 300
  evaluation_periods = 1
  threshold = 5 ## alert if we get >10 alb 5XX error
  # This dimension is what makes it per-client — each client has its own target group
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix[each.key]

  }
  alarm_actions = [var.sns_critical_arn]
  ok_actions = [var.sns_critical_arn]
  treat_missing_data = "notBreaching"
  alarm_description = "CRITICAL: ALB returning 5xx error . application code is failing "
}
# ── ALARM 2: No healthy tasks ────────────────────────────────────────────
# Fires when: ALL ECS tasks for one client fail the health check
# Means: site is completely unreachable for that client
resource "aws_cloudwatch_metric_alarm" "no_healthy_tasks" {
  for_each = toset(var.ecs_clients)

  alarm_name          = "CRITICAL-${each.key}-no-healthy-tasks"
  alarm_description   = "Client ${each.key}: zero tasks passing health check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1  # alarm if healthy count drops below 1

  dimensions = {
    LoadBalancer =  var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix[each.key]
  }

  alarm_actions = [var.sns_critical_arn]
  ok_actions    = [var.sns_critical_arn]
}


### RDS connection Exhaust
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name = "${var.project_name}-RDS-High-Connections"
  comparison_operator = "LessThanThreshold"
  metric_name = "DatabaseConnections"
  namespace = "AWS/RDS"
  statistic = "Average"

  period = 60
  evaluation_periods = 2
  threshold = 2 ## means alert at 65 connection i think our instance limit is 85 before it trigger

  dimensions = {
    DBInstanceIdentifier = "wordpress-hosting-db-instance"
  }
  alarm_actions = [var.sns_critical_arn]

  ok_actions = [var.sns_critical_arn]

  treat_missing_data = "breaching"
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
    CacheClusterId = "wordpress-hosting-valkey-cluster-001"
  }
  alarm_actions = [var.sns_critical_arn]
  ok_actions = [var.sns_critical_arn]
  treat_missing_data = "notBreaching"
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
    CacheClusterId =  "wordpress-hosting-valkey-cluster-001"
  }

  alarm_actions = [var.sns_critical_arn]
  treat_missing_data = "notBreaching"
  alarm_description = "WARNING: Cache is full and evicting data. Consider upgrading the ElastiCache node type."
}
# resource "aws_cloudwatch_metric_alarm" "requestcount" {
#   alarm_name = "${var.project_name}-request-count"
#   comparison_operator = 
# }

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
        width = 8
        height = 6
        properties = {
          metrics = [
                for client in var.ecs_clients :
                ["AWS/ECS" , "CPUUtilization","ClusterName", var.cluster_name , "ServiceName" , "${var.project_name}-${client}-service" ]
          ]
          view = "timeSeries"
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
        width = 8
        height = 6
        properties = {
          metrics = [
          
            for client in var.ecs_clients :
            ["AWS/ECS", "MemoryUtilization" , "ClusterName", var.cluster_name , "ServiceName" , "${var.project_name}-${client}-service"]
          ]
          view = "timeSeries"
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
        width = 8
        height = 6
        properties = {
          metrics =[
            ["AWS/RDS","DatabaseConnections" , "DBInstanceIdentifier" , "wordpress-hosting-db-instance"]
          ]
          view = "timeSeries"
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
        width =8
        height = 6
        properties ={
          metrics = [
            ["AWS/ApplicationELB","HTTPCode_Target_5XX_Count","LoadBalancer",var.alb_arn_suffix]
          ]
          view = "timeSeries"
          stacked = false
          region = "eu-north-1"
          title = "ALB 5xx Errors (Application Failures)"
          stat = "Sum"
        }
      } ,
      {
  type = "metric"
  x = 0
  y = 12
  width = 8
  height = 6

  properties = {
    metrics = [
      ["AWS/ApplicationELB","RequestCount","LoadBalancer",var.alb_arn_suffix]
    ]
    view = "timeSeries"
    region = "eu-north-1"
    title = "ALB Request Count (Traffic)"
    stat = "Sum"
  }
} ,

{
  type = "metric"
  x = 12
  y = 12
  width = 8
  height = 6

  properties = {
    metrics = [
      ["AWS/ApplicationELB","TargetResponseTime","LoadBalancer",var.alb_arn_suffix]
    ]
    view = "timeSeries"
    region = "eu-north-1"
    title = "ALB Latency"
  }
}

    ]
  })
}

##### alarms 
#### ERROR RATE % ALARM 
# resource "aws_cloudwatch_metric_alarm" "error_rate" {
#   for_each = toset(var.project_name)
#   alarm_name = "${var.project_name}-${each.key}-error_rate"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   threshold           = 0.5
#   alarm_description   = "Error rate > 0.5% for ${each.key}"

#   alarm_actions = [var.sns_critical_arn]

#   metric_query {
#     id = "errors"
#     metric {
#       namespace = "AWS/AppliccationELB"
#       metric_name = "HTTPCode_Target_5XX_Count"
#       stat = "Sum"
#       period = 300

#       dimensions = {
#         TargetGroup = var.tg_arn_suffix[each.key]
#       }
#     }
#   }
#   metric_query {
#     id = "requests"
#     metric {
#       namespace   = "AWS/ApplicationELB"
#       metric_name = "RequestCount"
#       stat        = "Sum"
#       period      = 300

#       dimensions = {
#         TargetGroup = var.tg_arn_suffix[each.key]
#       }
#     }
#   }
#   metric_query {
#     id = "error_rate"
#     expression = "(errors/MAX([requests,1])) * 100"
#     label = "${each.key} error rate"
#     return_data = true
#   }


# }

#### ERROR RATE % ALARM 
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  for_each = toset(var.ecs_clients) # FIXED: Changed from project_name to ecs_clients

  alarm_name          = "${var.project_name}-${each.key}-error_rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0.5
  alarm_description   = "Error rate > 0.5% for ${each.key}"

  alarm_actions = [var.sns_critical_arn]

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB" # FIXED: Spelling typo
      metric_name = "HTTPCode_Target_5XX_Count"
      stat        = "Sum"
      period      = 300

      dimensions = {
        TargetGroup = var.tg_arn_suffix[each.key]
      }
    }
  }
  
  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      stat        = "Sum"
      period      = 300

      dimensions = {
        TargetGroup = var.tg_arn_suffix[each.key]
      }
    }
  }
  
  metric_query {
    id          = "error_rate"
    expression  = "(errors/MAX([requests,1])) * 100"
    label       = "${each.key} error rate"
    return_data = true
  }
}
resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  for_each = toset(var.ecs_clients)

  alarm_name          = "${var.project_name}-${each.key}-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 2

  alarm_actions = [var.sns_critical_arn]

  metric_name = "TargetResponseTime"
  namespace   = "AWS/ApplicationELB"
  extended_statistic = "p99"
  period      = 300

  dimensions = {
    TargetGroup = var.tg_arn_suffix[each.value]
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_tasks_down" {
  for_each = toset(var.ecs_clients)

  alarm_name          = "${var.project_name}-${each.key}-tasks-down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 0

  alarm_actions = [var.sns_critical_arn]

  metric_name = "RunningTaskCount"
  namespace   = "ECS/ContainerInsights"
  statistic   = "Average"
  period      = 300

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = "wordpress-hosting-${each.key}-service"
  }
}

####### Dashboard
# resource "aws_cloudwatch_dashboard" "sre_dashboard" {
#   dashboard_name = "${var.project_name}-sre-dashboard"

#   dashboard_body = jsonencode({
#     widgets = flatten([
#       for client, tg in var.ecs_clients : {
#         type   = "metric"
#         # Safely calculates X grid coordinates
#         x      = (index(keys(var.ecs_clients), client) % 3) * 8 
#         y      = 0
#         width  = 8
#         height = 6

#         properties = {
#           title  = "${client} Error Rate (%)"
#           view   = "singleValue"
#           region = "eu-north-1"
#           period = 3600

#           metrics = [
#             [
#               {
#                 expression = "(m1/m2)*100",
#                 label      = "${client} error %",
#                 id         = "e1",
#                 stat       = "Sum" # Added stat here to ensure the math evaluates correctly
#               }
#             ],
#             [
#               "AWS/ApplicationELB",
#               "HTTPCode_Target_5XX_Count",
#               "TargetGroup",
#               tg,
#               { id = "m1", stat = "Sum", period = 3600, visible = false } # Added visible = false
#             ],
#             [
#               ".",
#               "RequestCount",
#               ".",
#               ".",
#               { id = "m2", stat = "Sum", period = 3600, visible = false } # Added visible = false
#             ]
#           ]
#         }
#       }
#     ])
#   })
# }

resource "aws_cloudwatch_dashboard" "sre_dashboard" {
  dashboard_name = "${var.project_name}-sre-dashboard"

  dashboard_body = jsonencode({
    widgets = flatten([
      # SRE FIX 1: Use idx and client for a list
      for idx, client in var.ecs_clients : { 
        type   = "metric"
        # SRE FIX 2: Use the idx directly for math. No keys() needed!
        x      = (idx % 3) * 8 
        y      = 0
        width  = 8
        height = 6

        properties = {
          title  = "${client} Error Rate (%)"
          view   = "singleValue"
          region = "eu-north-1"
          period = 3600

          metrics = [
            [
              {
                expression = "(m1/m2)*100",
                label      = "${client} error %",
                id         = "e1",
                stat       = "Sum"
              }
            ],
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "TargetGroup",
              # SRE FIX 3: Look up the Target Group string using the client name
              var.tg_arn_suffix[client], 
              { id = "m1", stat = "Sum", period = 3600, visible = false }
            ],
            [
              ".",
              "RequestCount",
              ".",
              ".",
              { id = "m2", stat = "Sum", period = 3600, visible = false }
            ]
          ]
        }
      }
    ])
  })
}
##################################
#             SLO              ###
#######################3##########

# error budget is 0.5% of requests per month per client = 3.6 hours.

# Burn rate = how fast you are consuming that budget compared to normal.

# Normal rate (1x): budget depletes over exactly 30 days. Fine.
# Fast burn (14x): at current error rate, ENTIRE 30-day budget consumed in 2 hours. Crisis.
# Slow burn (6x): budget consumed in 5 days. Not a crisis but will miss the SLO if unaddressed.

# Fast burn alarm: fires if error rate > 7% in last 1 hour (7% = 14 × 0.5%).
# Slow burn alarm: fires if error rate > 3% sustained over 6 hours (3% = 6 × 0.5%).


#### FAST BURN ALARM
resource "aws_cloudwatch_metric_alarm" "slo_fast_burn" {
  for_each = toset(var.ecs_clients)

    alarm_name          = "CRITICAL-${each.key}-slo-fast-burn"
  alarm_description   = "${each.key}: burning error budget 14x faster than allowed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 7
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate_1h"
    expression  = "(errors_1h / total_1h) * 100"
    label       = "Error rate % (1h window)"
    return_data = true
  }

  metric_query {
    id = "errors_1h"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 3600
      stat        = "Sum"
      dimensions  = {
        LoadBalancer = var.alb_arn_suffix
        TargetGroup  = var.tg_arn_suffix[each.key]
      }
    }
  }
  metric_query {
    id = "total_1h"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 3600
      stat        = "Sum"
      dimensions  = {
        LoadBalancer = var.alb_arn_suffix
        TargetGroup  = var.tg_arn_suffix[each.key]
      }
    }
  }

  alarm_actions = [var.sns_critical_arn]

}

### slow burn Alarm

resource "aws_cloudwatch_metric_alarm" "slo_slow_burn" {
  for_each = toset(var.ecs_clients)

  alarm_name          = "HIGH-${each.key}-slo-slow-burn"
  alarm_description   = "${each.key}: burning error budget 6x faster — will miss SLO in 5 days"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 3
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate_6h"
    expression  = "(errors_6h / total_6h) * 100"
    label       = "Error rate % (6h window)"
    return_data = true
  }

  metric_query {
    id = "errors_6h"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 21600
      stat        = "Sum"
      dimensions  = {
        LoadBalancer = var.alb_arn_suffix
        TargetGroup  = var.tg_arn_suffix[each.key]
      }
    }
  }

  metric_query {
    id = "total_6h"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 21600
      stat        = "Sum"
      dimensions  = {
        LoadBalancer = var.alb_arn_suffix
        TargetGroup  = var.tg_arn_suffix[each.key]
      }
    }
  }

  alarm_actions = [var.sns_critical_arn]
}






#### Dashboard new 
resource "aws_cloudwatch_dashboard" "sre_dashboard_1" {
  dashboard_name = "${var.project_name}-sre-dashboard_1"

  dashboard_body = jsonencode({
    widgets = flatten([
      # SRE FIX: Loop directly over the map!
      for client, tg_suffix in var.tg_arn_suffix : {
        type   = "metric"
        # Because tg_arn_suffix IS a map, keys() works perfectly here to get the index:
        x      = (index(keys(var.tg_arn_suffix), client) % 3) * 8 
        y      = 0
        width  = 8
        height = 6

        properties = {
          title  = "${client} Error Rate (%)"
          view   = "singleValue"
          region = "eu-north-1"
          period = 3600

          metrics = [
            [
              {
                expression = "(m1/m2)*100",
                label      = "${client} error %",
                id         = "e1",
                stat       = "Sum"
              }
            ],
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "TargetGroup",
              tg_suffix, # SRE FIX: Use the value directly from the map loop
              { id = "m1", stat = "Sum", period = 3600, visible = false }
            ],
            [
              ".",
              "RequestCount",
              ".",
              ".",
              { id = "m2", stat = "Sum", period = 3600, visible = false }
            ]
          ]
        }
      }
    ])
  })
}

# Budget warning alarm — fires when < 20% remaining
resource "aws_cloudwatch_metric_alarm" "budget_low" {
  # SRE FIX: Loop directly over the map!
  for_each = var.tg_arn_suffix 

  alarm_name          = "WARN-${each.key}-budget-80pct-consumed"
  alarm_description   = "${each.key}: 80% of monthly error budget consumed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorBudgetRemainingPercent"
  namespace           = "WordPress/SRE"
  period              = 3600
  statistic           = "Minimum"
  threshold           = 20 

  dimensions = { 
    ClientId = each.key # each.key is "client3"
  }

  alarm_actions = [var.sns_high_arn] 
}

#### ERROR RATE % ALARM 
resource "aws_cloudwatch_metric_alarm" "error_rate_1" {
  # SRE FIX: Loop directly over the map!
  for_each = var.tg_arn_suffix 

  alarm_name          = "${var.project_name}-${each.key}-error_rate_1"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0.5
  alarm_description   = "Error rate > 0.5% for ${each.key}"

  alarm_actions = [var.sns_critical_arn]

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      stat        = "Sum"
      period      = 300

      dimensions = {
        TargetGroup = each.value # SRE FIX: each.value is "targetgroup/..."
      }
    }
  }
  # ... (Repeat the each.value logic for the requests metric query)
}


##### event bridge 
# 6. Run every hour via EventBridge Schedule
resource "aws_cloudwatch_event_rule" "hourly" {
  name                = "${var.project_name}-error-budget-hourly"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "error_budget_target" {
  rule      = aws_cloudwatch_event_rule.hourly.name
  target_id = "TriggerErrorBudgetLambda"
  arn       = var.error_budget_arn
}

# # 7. SRE CRITICAL FIX: Allow EventBridge to actually invoke the Lambda!
# resource "aws_lambda_permission" "allow_eventbridge" {
#   statement_id  = "AllowExecutionFromCloudWatch"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.error_budget.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.hourly.arn
# }