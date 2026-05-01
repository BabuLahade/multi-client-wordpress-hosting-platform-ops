# FinOps Dashboard Showing $0 — Debug Guide

## Four Possible Causes (check in order)

### Cause 1 — Cost Explorer Not Enabled (most common)
AWS Cost Explorer must be explicitly enabled. It is NOT on by default.

1. Go to AWS Console → Billing → Cost Explorer
2. If you see "Enable Cost Explorer" button → click it
3. Wait 24 hours for data to appear

### Cause 2 — Missing IAM Permission

```bash
aws iam simulate-principal-policy \
  --policy-source-arn {lambda_role_arn} \
  --action-names ce:GetCostAndUsage \
  --query 'EvaluationResults[0].EvalDecision'
# Must return: "allowed"
```

Add to Terraform if missing:
```hcl
resource "aws_iam_role_policy" "finops_ce" {
  name = "finops-cost-explorer"
  role = aws_iam_role.finops_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ce:GetCostAndUsage", "ce:GetCostForecast"]
      Resource = "*"  # Cost Explorer does not support resource-level restrictions
    }]
  })
}
```

### Cause 3 — Resources Not Tagged Project=P1

```bash
# Verify ECS cluster has the tag
aws ecs describe-clusters \
  --clusters wordpress-hosting-cluster \
  --query 'clusters[0].tags'

# Expected: [{key: "Project", value: "P1"}, ...]
```

**Activate tag in Cost Allocation Tags:**
1. AWS Console → Billing → Cost Allocation Tags
2. Find `Project` tag → click Activate
3. Wait 24 hours

Add default_tags to Terraform provider to tag all resources automatically:
```hcl
provider "aws" {
  region = "ap-south-1"
  default_tags { tags = { Project = "P1", ManagedBy = "terraform" } }
}
```

### Cause 4 — 24-Hour Data Lag
Cost Explorer always has minimum 24-hour lag. Today's costs appear tomorrow.

**Fix in Lambda:** always query yesterday's date:
```python
from datetime import datetime, timedelta
end_date = datetime.utcnow().date()
start_date = end_date - timedelta(days=1)  # always yesterday
```

---

## Fixed Lambda Code (key changes)

```python
import boto3
from datetime import datetime, timedelta

# Cost Explorer is ALWAYS in us-east-1 regardless of your region
ce = boto3.client('ce', region_name='us-east-1')
cw = boto3.client('cloudwatch', region_name='ap-south-1')

def lambda_handler(event, context):
    end_date = datetime.utcnow().date()
    start_date = end_date - timedelta(days=1)  # yesterday — avoids lag issue
    
    response = ce.get_cost_and_usage(
        TimePeriod={'Start': str(start_date), 'End': str(end_date)},
        Granularity='DAILY',
        Filter={'Tags': {'Key': 'Project', 'Values': ['P1']}},
        GroupBy=[{'Type': 'DIMENSION', 'Key': 'SERVICE'}],
        Metrics=['UnblendedCost']
    )
    
    if not response['ResultsByTime'] or not response['ResultsByTime'][0]['Groups']:
        print("No data — check: Cost Explorer enabled? IAM permission? Tags activated?")
        return
    
    total = 0.0
    for group in response['ResultsByTime'][0]['Groups']:
        cost = float(group['Metrics']['UnblendedCost']['Amount'])
        service = group['Keys'][0]
        total += cost
        print(f"  {service}: ${cost:.4f}")
    
    cw.put_metric_data(
        Namespace='WordPress/FinOps',
        MetricData=[{'MetricName': 'DailyTotalCost', 'Value': total, 'Unit': 'None',
                     'Dimensions': [{'Name': 'Project', 'Value': 'P1'}]}]
    )
    print(f"Total: ${total:.4f} for {start_date}")
```

## Expected output when working
```
ECS Fargate:   ~$0.50/day  ($15/month)
RDS MySQL:     ~$1.00/day  ($30/month)
ALB:           ~$0.60/day  ($18/month)
ElastiCache:   ~$0.43/day  ($13/month)
NAT Gateway:   ~$0.33/day  ($10/month)
CloudFront+S3: ~$0.17/day  ($5/month)
Total:         ~$2.50/day  ($75/month)
```
