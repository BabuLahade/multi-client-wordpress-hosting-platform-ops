output "cloudwatch_log_group_name" {
    value={
        for k ,v in aws_cloudwatch_log_group.wordpress_logs : k=>v.name
    }
}
output "alb_5xx_alarm" {
    value ={
        for k , v in aws_cloudwatch_metric_alarm.alb_5xx_errors : k=>v.alarm_name
    }

}
output "ecs_memory_high" {
    value = {
        for k , v in aws_cloudwatch_metric_alarm.ecs_memory_high : k=>v.alarm_name
    }
}