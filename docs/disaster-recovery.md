# Runbook — Disaster Recovery

> **RTO target: < 30 minutes**  
> **RPO target: < 1 hour**  
> Last tested: April 2026

---

## When to use this runbook

Use this runbook when the primary AWS region (ap-south-1) is experiencing a service disruption that affects the ability to serve client WordPress sites — not for individual service failures like a single ECS task crash (handled by auto-healing) or a single AZ RDS failover (handled automatically by Multi-AZ).

Triggers for this runbook:

- AWS ap-south-1 widespread service disruption
- RDS Multi-AZ failover did not complete automatically within 5 minutes
- ECS control plane unavailable — services cannot be updated or tasks cannot be placed
- All three client sites returning errors simultaneously with no auto-healing resolution

---

## Step 1 — Confirm it is a regional issue (2 minutes)

Before triggering DR, confirm the scope of the problem.

```bash
# Check AWS service health
open https://health.aws.amazon.com/health/status

# Check if specific services are affected
aws health describe-events --filter services=ECS,RDS,ELB --region ap-south-1

# Quick check: can you reach the ALB?
curl -I https://clienta.com
```

If the issue is a single service (e.g., only RDS is affected), use the service-specific runbook instead:
- RDS issues → `runbooks/db-connections.md`
- ECS issues → `runbooks/high-error-rate.md`
- Slow responses → `runbooks/slow-response.md`

---

## Step 2 — RDS failover confirmation (5 minutes)

RDS Multi-AZ failover is automatic. Check if it completed:

```bash
# Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier wordpress-platform-db \
  --query 'DBInstances[0].{Status:DBInstanceStatus,AZ:AvailabilityZone,MultiAZ:MultiAZ}'

# Check recent RDS events for failover confirmation
aws rds describe-events \
  --source-identifier wordpress-platform-db \
  --source-type db-instance \
  --duration 60  # last 60 minutes
```

**Expected:** Status should return to `available` within 87 seconds of failover initiation (measured in testing). If status has not recovered after 5 minutes, proceed to Step 5.

---

## Step 3 — Check ECS service health (3 minutes)

```bash
# Check running task count per client service
for client in clienta clientb clientc; do
  echo "=== $client ==="
  aws ecs describe-services \
    --cluster wordpress-cluster \
    --services wordpress-$client \
    --query 'services[0].{Running:runningCount,Desired:desiredCount,Status:status}'
done

# Check for recent service events (stop reasons)
aws ecs describe-services \
  --cluster wordpress-cluster \
  --services wordpress-clienta \
  --query 'services[0].events[0:5]'
```

If services are running but sites are unreachable, check the ALB target groups:

```bash
aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN_CLIENTA
```

---

## Step 4 — Force ECS task replacement (5 minutes)

If tasks are running but unhealthy, force a replacement:

```bash
# Force new deployment for all three services simultaneously
for client in clienta clientb clientc; do
  aws ecs update-service \
    --cluster wordpress-cluster \
    --service wordpress-$client \
    --force-new-deployment \
    --region ap-south-1
  echo "Triggered replacement for $client"
done
```

New tasks will start, run `entrypoint.sh` (which re-reads Secrets Manager), and pass the ALB health check before old tasks stop.

---

## Step 5 — Manual Terraform apply from DR environment (10 minutes)

If the control plane is unavailable and you need to rebuild from Terraform:

```bash
# Clone repo if not already local
git clone https://github.com/yourusername/wordpress-hosting-platform
cd wordpress-hosting-platform

# Initialise Terraform with remote state
cd terraform/environments/production
terraform init

# Review current state
terraform plan

# Apply — this will reconcile any drift or rebuild missing resources
terraform apply -auto-approve
```

This step assumes remote state in S3 is accessible. If S3 is also unavailable, the state file is backed up to `s3-dr-backup/terraform.tfstate` in the secondary region.

---

## Step 6 — Route 53 failover to secondary region (5 minutes)

Route 53 health-check-based failover is configured but requires the secondary region infrastructure to be running. If the primary region is fully unavailable:

```bash
# Check Route 53 health check status
aws route53 get-health-check-status \
  --health-check-id $HEALTH_CHECK_ID

# If health check is unhealthy, Route 53 should have already switched traffic
# to the secondary region endpoint. Verify:
dig +short clienta.com
# Should return the secondary region ALB IP if failover occurred
```

If Route 53 has not automatically failed over, manually update the DNS record:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://dr/manual-failover-dns.json
```

---

## Step 7 — Verify client sites are serving (2 minutes)

```bash
# Check all three client sites
for client in clienta clientb clientc; do
  status=$(curl -s -o /dev/null -w "%{http_code}" https://$client.com)
  echo "$client: HTTP $status"
done

# Expected: all three return 200
```

---

## Post-recovery

After the incident is resolved:

1. Write an incident report (template in `docs/incident-report-template.md`)
2. Add the incident to `FAILURES.md` with root cause and changes made
3. Review which monitoring or automation could have detected the issue earlier
4. Update this runbook if any steps were incorrect or missing

---

**Tested failover times (measured):**  
RDS Multi-AZ failover: 87 seconds  
ECS task replacement: 23 seconds  
Manual Terraform apply (full rebuild): ~10 minutes  

---

*Babu Lahade · Last tested: April 2026*
