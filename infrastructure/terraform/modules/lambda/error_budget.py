# import boto3
# from datetime import datetime , timedelta

# CLIENTS = ['client3','client4','client5']
# SLO_TARGET = 0.995   # 99.5 availability

# def handler(event,context):
#     cw = boto3.client('cloudwatch', region_name='eu-north-1')
    
#     for client_id in CLIENTS:
#         end_time   = datetime.utcnow()
#         start_time = end_time - timedelta(days=30)
        
#         ### 30 days tptal from cloudwatch
#         total  = get_alb_metric(cw, 'RequestCount', client_id, start_time, end_time)
#         errors = get_alb_metric(cw, 'HTTPCode_Target_5XX_Count', client_id, start_time, end_time)
        
#         if total == 0:
#             print(f'{client_id}: no traffic — skipping')
#             continue
        
#         # How much budget was allowed vs how much was used
#         budget_allowed   = total * (1 - SLO_TARGET)   # 0.5% of all requests
#         budget_remaining = max(0, budget_allowed - errors)
#         remaining_pct    = (budget_remaining / budget_allowed) * 100

#         print(f'{client_id}: {remaining_pct:.1f}% budget remaining')

#          # Publish as custom metric — Grafana will read this
#         cw.put_metric_data(
#             Namespace='WordPress/SRE',
#             MetricData=[{
#                 'MetricName': 'ErrorBudgetRemainingPercent',
#                 'Dimensions': [{'Name': 'ClientId', 'Value': client_id}],
#                 'Value': round(remaining_pct, 2),
#                 'Unit': 'Percent',
#                 'Timestamp': end_time
#             }]
#         )
        
# def get_alb_metric(cw, metric_name, client_id, start_time, end_time):
#     """Get sum of an ALB metric for a specific client target group over a time range"""
#     tg_arn_suffix = get_target_group_arn_suffix(client_id)  # implement based on your TG names

#     response = cw.get_metric_statistics(
#         Namespace='AWS/ApplicationELB',
#         MetricName=metric_name,
#         Dimensions=[
#             {'Name': 'TargetGroup', 'Value': tg_arn_suffix},
#             {'Name': 'LoadBalancer', 'Value': get_alb_arn_suffix()},
#         ],
#         StartTime=start_time,
#         EndTime=end_time,
#         Period=int((end_time - start_time).total_seconds()),
#         Statistics=['Sum']
#     )

#     datapoints = response.get('Datapoints', [])
#     return datapoints[0]['Sum'] if datapoints else 0

import os
import json
import boto3
from datetime import datetime, timedelta

# Pull environment variables injected by Terraform
SLO_TARGET = float(os.environ.get('SLO_TARGET', '0.995'))
# TARGET_GROUPS will be a JSON string from Terraform: {"client3": "targetgroup/...", ...}
TARGET_GROUPS = json.loads(os.environ.get('TARGET_GROUPS', '{}'))

# Initialize outside the handler so the connection is reused on warm starts
cw = boto3.client('cloudwatch', region_name='eu-north-1')

def handler(event, context):
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=30)
    
    for client_id, tg_arn_suffix in TARGET_GROUPS.items():
        print(f"Processing Error Budget for {client_id}...")
        
        # Get 30 days of data
        total = get_alb_metric(cw, 'RequestCount', tg_arn_suffix, start_time, end_time)
        errors = get_alb_metric(cw, 'HTTPCode_Target_5XX_Count', tg_arn_suffix, start_time, end_time)
        
        if total == 0:
            print(f'{client_id}: no traffic in 30 days — skipping')
            continue
        
        # SRE Math: How much budget was allowed vs used
        budget_allowed = total * (1.0 - SLO_TARGET)   # 0.5% of all requests
        budget_remaining = max(0, budget_allowed - errors)
        remaining_pct = (budget_remaining / budget_allowed) * 100

        print(f'{client_id}: {remaining_pct:.1f}% budget remaining ({errors} errors out of {budget_allowed:.0f} allowed)')

        # Publish custom metric back to CloudWatch
        cw.put_metric_data(
            Namespace='WordPress/SRE',
            MetricData=[{
                'MetricName': 'ErrorBudgetRemainingPercent',
                'Dimensions': [{'Name': 'ClientId', 'Value': client_id}],
                'Value': round(remaining_pct, 2),
                'Unit': 'Percent',
                'Timestamp': end_time
            }]
        )
        
    return {"status": 200, "message": "Error budgets updated successfully"}

def get_alb_metric(cw, metric_name, tg_arn_suffix, start_time, end_time):
    """Fetches ALB metrics in 24-hour chunks to bypass AWS API limits"""
    response = cw.get_metric_statistics(
        Namespace='AWS/ApplicationELB',
        MetricName=metric_name,
        Dimensions=[
            {'Name': 'TargetGroup', 'Value': tg_arn_suffix}
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=86400, # Max AWS limit: 24 hours
        Statistics=['Sum']
    )

    # Sum all the daily buckets returned by AWS
    datapoints = response.get('Datapoints', [])
    total_sum = sum(dp['Sum'] for dp in datapoints)
    
    return total_sum

