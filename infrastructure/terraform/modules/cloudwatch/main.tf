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
  comparison_operator = "GreaterThanThreshold"
  metric_name = "DatabaseConnections"
  namespace = "AWS/RDS"
  statistic = "Average"

  period = 60
  evaluation_periods = 2
  threshold = 65 ## means alert at 65 connection i think our instance limit is 85 before it trigger

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
# resource "aws_cloudwatch_metric_alarm" "error_rate" {
#   for_each = toset(var.ecs_clients) # FIXED: Changed from project_name to ecs_clients

#   alarm_name          = "${var.project_name}-${each.key}-error_rate"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   threshold           = 0.5
#   alarm_description   = "Error rate > 0.5% for ${each.key}"

#   alarm_actions = [var.sns_critical_arn]

#   metric_query {
#     id = "errors"
#     metric {
#       namespace   = "AWS/ApplicationELB" # FIXED: Spelling typo
#       metric_name = "HTTPCode_Target_5XX_Count"
#       stat        = "Sum"
#       period      = 300

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
#     id          = "error_rate"
#     expression  = "(errors/MAX([requests,1])) * 100"
#     label       = "${each.key} error rate"
#     return_data = true
#   }
# }
#### ERROR RATE % ALARM 
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  for_each = var.tg_arn_suffix 

  alarm_name          = "${var.project_name}-${each.key}-error_rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0.5
  alarm_description   = "Error rate > 0.5% for ${each.key}"

  alarm_actions = [var.sns_critical_arn]
  treat_missing_data  = "notBreaching"
  metric_query {
    id          = "errors"
    return_data = false # FIX 1: Hides this raw data from the alarm trigger
    
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      stat        = "Sum"
      period      = 300

      dimensions = {
      
        TargetGroup = each.value 
      }
    }
  }
  
  metric_query {
    id          = "requests"
    return_data = false # FIX 1: Hides this raw data from the alarm trigger
    
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      stat        = "Sum"
      period      = 300

      dimensions = {
        TargetGroup = each.value
      }
    }
  }
  
  metric_query {
    id          = "error_rate"
    # FIX 2: Replaced MAX() with IF() to satisfy AWS CloudWatch Math rules
    expression  = "IF(requests > 0, (errors/requests)*100, 0)"
    label       = "${each.key} error rate"
    return_data = true  # FIX 1: This is the ONLY metric allowed to trigger the alarm
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
    LoadBalancer = var.alb_arn_suffix
    TargetGroup = var.tg_arn_suffix[each.value]
  }
  treat_missing_data = "notBreaching"
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
# resource "aws_cloudwatch_metric_alarm" "error_rate_1" {
#   # SRE FIX: Loop directly over the map!
#   for_each = var.tg_arn_suffix 

#   alarm_name          = "${var.project_name}-${each.key}-error_rate_1"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   threshold           = 0.5
#   alarm_description   = "Error rate > 0.5% for ${each.key}"

#   alarm_actions = [var.sns_critical_arn]

#   metric_query {
#     id = "errors"
#     metric {
#       namespace   = "AWS/ApplicationELB"
#       metric_name = "HTTPCode_Target_5XX_Count"
#       stat        = "Sum"
#       period      = 300

#       dimensions = {
#         TargetGroup = each.value # SRE FIX: each.value is "targetgroup/..."
#       }
#     }
#   }
#   # ... (Repeat the each.value logic for the requests metric query)
# }


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

###### HIGH ALARMS 
# ── p99 response time slow (per client) ──────────────────────────────
# Fires when: p99 > 2 seconds for 10 minutes
# First check: RDS CPU. Second check: EFS BurstCreditBalance.
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  for_each            = toset(var.ecs_clients)
  alarm_name          = "HIGH-${each.key}-p99-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2        # 2 × 5min = 10 minutes sustained
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p99"    # not Average — p99 latency
  threshold           = 2        # seconds
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix[each.key]
  }
  alarm_actions = [var.sns_high_arn]
}

# ── ECS CPU sustained high (per client) ───────────────────────────────
# Fires when: average CPU > 85% for 10 minutes
# First check: auto-scaling — did it trigger? If yes: real traffic spike.
# If no: likely a PHP process in an infinite loop.
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  for_each            = toset(var.ecs_clients)
  alarm_name          = "HIGH-${each.key}-ecs-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CpuUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = "wordpress-hosting-${each.key}-service"
  }
  alarm_actions = [var.sns_high_arn]
}

# ── RDS connections approaching limit ────────────────────────────────
# Fires when: connections > 85 (db.t3.micro limit = 100)
# At 85, next traffic burst could hit 100 causing "Too many connections"
# for all three clients simultaneously — your most shared failure mode
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "HIGH-rds-connections"
  alarm_description   = "RDS approaching 100 connection limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 85
  dimensions = { DBInstanceIdentifier = "wordpress-hosting-db-instance" }
  alarm_actions = [var.sns_high_arn]
}

# ── RDS CPU high ───────────────────────────────────────────────────────
# Fires when: RDS CPU > 80% for 5 minutes
# Usually caused by slow queries — run SHOW PROCESSLIST to find culprit
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "HIGH-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions = { 
    DBInstanceIdentifier = "wordpress-hosting-db-instance"  }
  alarm_actions = [var.sns_high_arn]
}

# ── EFS burst credits low ─────────────────────────────────────────────
# Fires when: burst credits < 1 million
# WHY THIS MATTERS: when credits hit zero, EFS I/O drops from burst
# speed to 50KB/s baseline. WordPress becomes 8-10 seconds per page.
# This is a slow-moving crisis you can see coming hours in advance.
resource "aws_cloudwatch_metric_alarm" "efs_credits_low" {
  alarm_name          = "WARN-efs-burst-credits-low"
  alarm_description   = "EFS burst credits running low — I/O degradation risk"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BurstCreditBalance"
  namespace           = "AWS/EFS"
  period              = 3600   # check hourly
  statistic           = "Minimum"
  threshold           = 85
  dimensions = { 
    FileSystemId =   var.efs_file_system_id
    }
  alarm_actions = [var.sns_high_arn]
}

# ── Valkey memory high ────────────────────────────────────────────────
# Fires when: memory > 80%
# Above 80%, Valkey evicts cache keys. Cache miss rate increases.
# DB load increases. Response times increase.
resource "aws_cloudwatch_metric_alarm" "valkey_memory" {
  alarm_name          = "WARN-valkey-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions = { 
    CacheClusterId =  "wordpress-hosting-valkey-cluster-001"
    }
  alarm_actions = [var.sns_high_arn]
}

# ── SSL certificate expiry ────────────────────────────────────────────
# Fires when: certificate expires in < 30 days
# ACM auto-renews but only if DNS validation records are correct.
# If someone deleted the CNAME validation record, auto-renewal fails.
resource "aws_cloudwatch_metric_alarm" "ssl_expiry" {
  for_each            = toset(var.ecs_clients)
  alarm_name          = "WARN-${each.key}-ssl-expiry-30d"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = 86400   # check daily
  statistic           = "Minimum"
  threshold           = 30
  dimensions = { 
    CertificateArn = var.certificate_arn
   }
  alarm_actions = [var.sns_high_arn]
}

# ── ECS at maximum capacity ───────────────────────────────────────────
# Fires when: RunningTaskCount == MaximumCapacity (cannot scale further)
# Auto-scaling cannot add more tasks. If traffic continues growing,
# response times will degrade. Check if traffic source is legitimate.
resource "aws_cloudwatch_metric_alarm" "ecs_max_capacity" {
  for_each            = toset(var.ecs_clients)
  alarm_name          = "WARN-${each.key}-ecs-max-capacity"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Maximum"
  threshold           = 5   # your maximum task count — adjust to match your config
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = "wordpress-hosting-${each.key}-service"
  }
  alarm_actions = [var.sns_high_arn]
}
         # ==========================================
         # FINOPS Dashboard and SLO Dashboard
         # ==========================================

resource "aws_cloudwatch_dashboard" "slo_finops_dashboard" {
  dashboard_name = "${var.project_name}-SLO-FinOps"

  dashboard_body = jsonencode({
    widgets = flatten([
      
   
      [for client, tg_suffix in var.tg_arn_suffix : {
        type   = "metric"
        x      = (index(keys(var.tg_arn_suffix), client) % 3) * 8 
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "${client} - Error Budget Remaining (%)"
          view    = "gauge" 
          region  = "eu-north-1"
          period  = 86400
          stat    = "Average"
          yAxis   = { left = { min = 0, max = 100 } }
          metrics = [
            ["WordPress/SRE", "ErrorBudgetRemainingPercent", "ClientId", client]
          ]
          annotations = {
            horizontal = [
              { color = "#d62728", value = 20, label = "CRITICAL (Investigate)" },
              { color = "#ff7f0e", value = 50, label = "WARNING" }
            ]
          }
        }
      }],

      
      [{
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 8
        properties = {
          title   = "Platform Error Budget Burn-down (30 Days)"
          view    = "timeSeries"
          region  = "eu-north-1"
          period  = 3600
          stacked = false
          # We dynamically inject all clients onto a single line graph
          metrics = [for c in keys(var.tg_arn_suffix) : 
            ["WordPress/SRE", "ErrorBudgetRemainingPercent", "ClientId", c]
          ]
        }
      }],

      
      [
        # Daily Spend 
        {
          type   = "metric"
          x      = 0
          y      = 14
          width  = 16
          height = 8
          properties = {
            title   = "Daily AWS Spend per Service ($)"
            view    = "bar"
            stacked = true
            region  = "eu-north-1"
            period  = 86400
            metrics = [
              ["WordPress/FinOps", "DailyCost", "Service", "AmazonECS"],
              [".", ".", ".", "AmazonRDS"],
              [".", ".", ".", "AmazonEC2"], 
              [".", ".", ".", "AmazonEFS"]
            ]
          }
        },
        # Cost per Client (Pie Chart)
        {
          type   = "metric"
          x      = 16
          y      = 14
          width  = 8
          height = 8
          properties = {
            title   = "Monthly Cost Distribution by Client"
            view    = "pie"
            region  = "eu-north-1"
            period  = 2592000 
            metrics = [for c in keys(var.tg_arn_suffix) : 
              ["WordPress/FinOps", "CostPerClient", "ClientId", c]
            ]
          }
        }
      ]
    ])
  })
}

resource "aws_cloudwatch_metric_alarm" "no_healthy_hosts" {
  for_each = toset(var.ecs_clients)

  alarm_name          = "CRITICAL-${each.key}-zero-healthy-targets"
  alarm_description   = "ALL targets deregistered for ${each.key} — site completely down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"  # ← CRITICAL: no data = alarm, not OK

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix[each.key]
  }

  alarm_actions = [var.sns_critical_arn]
  ok_actions    = [var.sns_critical_arn]
}
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  for_each = toset(var.ecs_clients)

  alarm_name          = "CRITICAL-${each.key}-alb-5xx"
  alarm_description   = "ALB returning 5xx for ${each.key} — no healthy targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"  # ← ALB-generated errors, not target errors
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix[each.key]
  }

  alarm_actions = [var.sns_critical_arn]
}



############3 Logging Querry ##########


resource "aws_cloudwatch_query_definition" "sre_wp_crashes" {
  name = "WordPress-SRE/02 - PHP & Database Errors"
  log_group_names = [
    "/ecs/${var.project_name}-client3",
    "/ecs/${var.project_name}-client4",
    "/ecs/${var.project_name}-client5"
  ]

  query_string = <<EOF
fields @timestamp, @logStream, @message
| filter @message like /Fatal error/ or @message like /database connection/
| sort @timestamp desc
| limit 20
EOF
}
resource "aws_cloudwatch_query_definition" "sre_nginx_5xx" {
  name = "WordPress-SRE/01 - NGINX 5xx Errors"

  log_group_names = [
    # "/ecs/${var.project_name}-client3",
    # "/ecs/${var.project_name}-client4",
    # "/ecs/${var.project_name}-client5"
    for client in keys(var.tg_arn_suffix) : "/ecs/${var.project_name}-${client}"
  ]

  query_string = <<EOF
parse @message '* - - [*] "* * *" * *' as clientIP, timestamp, method, uri, protocol, statusCode, bytes
| filter statusCode >= 500
| fields @timestamp, statusCode, uri, clientIP
| sort @timestamp desc
| limit 20
EOF
}
resource "aws_cloudwatch_query_definition" "sre_top_urls" {
  name = "WordPress-SRE/03 - Top Requested URLs"
  log_group_names = [
    # "/ecs/${var.project_name}-client3",
    # "/ecs/${var.project_name}-client4",
    # "/ecs/${var.project_name}-client5"
    for client in keys(var.tg_arn_suffix) : "/ecs/${var.project_name}-${client}"
  ]

  query_string = <<EOF
parse @message '* - - [*] "* * *" * *' as clientIP, timestamp, method, uri, protocol, statusCode, bytes
| stats count() as requestCount by uri
| sort requestCount desc
| limit 10
EOF
}
resource "aws_cloudwatch_query_definition" "sre_error_trend" {
  name = "WordPress-SRE/04 - Hourly Error Trend"
  log_group_names = [
    # "/ecs/${var.project_name}-client3",
    # "/ecs/${var.project_name}-client4",
    # "/ecs/${var.project_name}-client5"
    for client in keys(var.tg_arn_suffix) : "/ecs/${var.project_name}-${client}"
  ]

  query_string = <<EOF
parse @message '* - - [*] "* * *" * *' as clientIP, timestamp, method, uri, protocol, statusCode, bytes
| filter statusCode >= 400
| stats count() as ErrorCount by bin(1h)
| sort @timestamp desc
EOF
}


resource "aws_cloudwatch_query_definition" "sre_security_brute_force" {
  name = "WordPress-SRE-01-SecurityBruteForce&BotAttacks"
  log_group_names = [for client in keys(var.tg_arn_suffix) : "/ecs/${var.project_name}-${client}"]

  query_string = <<EOF
parse @message '* - - [*] "* * *" * *' as ip, time, method, uri, protocol, status, bytes
| filter uri like "/wp-login.php" or uri like "/xmlrpc.php"
| stats count() as AttackAttempts by ip
| sort AttackAttempts desc
| limit 10
EOF
}


resource "aws_cloudwatch_query_definition" "sre_finops_bandwidth" {
  name = "WordPress-SRE-2FinOpsHighestBandwidthConsumers(IPs)"
  log_group_names = [for c in keys(var.tg_arn_suffix) : "/ecs/${var.project_name}-${c}"]

  query_string = <<EOF
parse @message '* - - [*] "* * *" * *' as ip, time, method, uri, protocol, status, bytes
| filter status == 200
| stats sum(bytes)/1024/1024 as MegabytesDownloaded by ip
| sort MegabytesDownloaded desc
| limit 10
EOF
}


resource "aws_cloudwatch_query_definition" "sre_platform_crashes" {
  name = "WordPress-SRE-03AppGlobalPHPFatals&DBDrops"
  log_group_names = [for c in keys(var.tg_arn_suffix) : "/ecs/${var.project_name}-${c}"]

  query_string = <<EOF
fields @timestamp, @logStream, @message
| filter @message like /Fatal error/ or @message like /database connection/ or @message like /Allowed memory size/
| sort @timestamp desc
| limit 50
EOF
}


resource "aws_cloudwatch_query_definition" "sre_incident_timeline" {
  name = "WordPress-SRE-04-Incident5xxErrorTimeline(5-MinBins)"
  log_group_names = [for c in keys(var.tg_arn_suffix) : "/ecs/${var.project_name}-${c}"]

  query_string = <<EOF
parse @message '* - - [*] "* * *" * *' as ip, time, method, uri, protocol, status, bytes
| filter status >= 500
| stats count() as CriticalErrors by bin(5m)
| sort @timestamp desc
EOF
}
   
