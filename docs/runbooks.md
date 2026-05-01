# Runbook: High DB Connections

**Alarm:** `HIGH-rds-connections-high`
**Threshold:** DatabaseConnections > 85
**Hard limit:** db.t3.micro supports ~100 connections total across all 3 clients

At 100 connections: new PHP requests fail with MySQL error `1040: Too many connections` → 5xx errors → error budget burns.

---

## Step 1 — Identify which client is consuming connections

```bash
mysql -h {rds_endpoint} -u admin -p -e "
  SELECT db, COUNT(*) as connections,
    SUM(CASE WHEN command='Sleep' THEN 1 ELSE 0 END) as idle,
    SUM(CASE WHEN command!='Sleep' THEN 1 ELSE 0 END) as active
  FROM information_schema.processlist
  GROUP BY db ORDER BY connections DESC;"
```

---

## Step 2 — Kill idle connections OR restart ECS tasks

**Kill idle connections (precise):**
```bash
mysql -h {rds_endpoint} -u admin -p -e "
  SELECT CONCAT('KILL CONNECTION ', id, ';')
  FROM information_schema.processlist
  WHERE command='Sleep' AND time>60 AND db='wp_clienta';" > /tmp/kill.sql
mysql -h {rds_endpoint} -u admin -p < /tmp/kill.sql
```

**Restart ECS tasks (faster — releases all connections for that client):**
```bash
aws ecs update-service \
  --cluster wordpress-hosting-cluster \
  --service wordpress-{client}-svc \
  --force-new-deployment
```

---

## Step 3 — Check for locked queries (auto-healer should have caught this)

```bash
mysql -h {rds_endpoint} -u admin -p -e "
  SELECT r.trx_mysql_thread_id waiting_thread,
         b.trx_mysql_thread_id blocking_thread,
         b.trx_query blocking_query
  FROM information_schema.innodb_lock_waits w
  JOIN information_schema.innodb_trx b ON b.trx_id=w.blocking_trx_id
  JOIN information_schema.innodb_trx r ON r.trx_id=w.requesting_trx_id;"

# Kill blocking query
mysql -h {rds_endpoint} -u admin -p -e "KILL QUERY {blocking_thread_id};"
```

---

## Step 4 — RDS failover check

```bash
aws rds describe-db-instances \
  --db-instance-identifier wordpress-hosting-db \
  --query 'DBInstances[0].{status:DBInstanceStatus,az:AvailabilityZone}'
```

**Status = `failing-over`:** Wait ~87 seconds. Do NOT restart ECS tasks during failover — they will reconnect automatically.

---

## Monitor recovery

```bash
watch -n 15 'aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=wordpress-hosting-db \
  --period 60 --statistics Maximum \
  --start-time $(date -d "5 minutes ago" -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --query "Datapoints[-1].Maximum"'
```

Target: connections < 30 within 5 minutes of fix.

**Long-term fix:** RDS Proxy pools connections — 1,000 PHP workers → 20 RDS connections. See ADR-007.

#############################

# Runbook: High Error Rate

**Alarm:** `CRITICAL-{client}-alb-5xx` or `CRITICAL-{client}-5xx-spike`
**Threshold:** HTTPCode_ELB_5XX_Count > 3 in 60 seconds
**SLO Impact:** Directly burns error budget — fast-burn alarm likely follows

---

## Quick Scope Check (2 min)

```bash
# Is it one client or all clients?
aws ecs describe-services \
  --cluster wordpress-hosting-cluster \
  --services wordpress-clienta-svc wordpress-clientb-svc wordpress-clientc-svc \
  --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount}'
```

- **One client only** → application/container issue
- **All clients** → infrastructure issue (RDS, Valkey, VPC, ALB)

---

## Step 1 — Check if tasks crashed (zero running tasks)

```bash
# If runningCount = 0 for affected client → INC-003 pattern
aws ecs update-service \
  --cluster wordpress-hosting-cluster \
  --service wordpress-{client}-svc \
  --force-new-deployment
```

The `HealthyHostCount` and `RunningTaskCount` CRITICAL alarms should also be firing. ALB errors are `HTTPCode_ELB_5XX_Count` not `HTTPCode_Target_5XX_Count` when tasks are deregistered.

---

## Step 2 — Check task logs for error reason

```bash
aws logs filter-log-events \
  --log-group-name /ecs/wordpress-{client} \
  --start-time $(date -d '10 minutes ago' +%s000) \
  --filter-pattern "ERROR" \
  --query 'events[*].message' --output text | head -30
```

| Log message | Cause | Action |
|-------------|-------|--------|
| `connection refused` to RDS | DB down | Check RDS status |
| `could not connect to Redis` | Valkey down | Check ElastiCache |
| `1024 worker_connections are not enough` | Traffic spike (INC-005) | Scale ECS or enable WAF |
| `PHP Fatal error` | App crash | Check WordPress config |

---

## Step 3 — Check recent deployment (regression)

```bash
# Get current task definition revision
aws ecs describe-services \
  --cluster wordpress-hosting-cluster \
  --services wordpress-{client}-svc \
  --query 'services[0].taskDefinition'
```

If deployed in last 30 min and rollback Lambda did not auto-trigger:

```bash
# Manual rollback to previous revision
aws ecs update-service \
  --cluster wordpress-hosting-cluster \
  --service wordpress-{client}-svc \
  --task-definition wordpress-{client}:{PREVIOUS_REVISION}
```

---

## Step 4 — Verify resolution

```bash
# Watch HTTPCode_ELB_5XX_Count drop to 0
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_ELB_5XX_Count \
  --dimensions Name=LoadBalancer,Value={alb_arn_suffix} \
  --period 60 --statistics Sum \
  --start-time $(date -d '5 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)
```

After resolving: add incident entry to FAILURES.md if root cause is new.


########################################

# Runbook: Slow Response / High Latency

**Alarm:** `HIGH-{client}-p99-latency-high`
**Threshold:** TargetResponseTime p99 > 2 seconds for 2 consecutive periods

---

## Quick Diagnosis Tree

```
p99 > 2s
    ├── EFS BurstCreditBalance alarm firing?
    │   └── YES → INC-002 pattern → Step 1 (EFS)
    ├── RDS DatabaseConnections > 70?
    │   └── YES → DB pressure → Step 2 (RDS)
    ├── Valkey CacheHitRate < 60%?
    │   └── YES → Cache miss storm → Step 3 (Valkey)
    ├── ECS CPU > 85%?
    │   └── YES → Compute saturation → Step 4 (scale ECS)
    └── None of above → Recent deployment? → Step 5
```

---

## Step 1 — EFS Burst Credits (INC-002 Pattern)

Most common cause of gradual latency increase with no errors.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name BurstCreditBalance \
  --dimensions Name=FileSystemId,Value={efs_id} \
  --period 300 --statistics Minimum \
  --start-time $(date -d '2 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)
```

**Credits < 500,000:** EFS in baseline mode (50KB/s). 
- Verify S3 Offload Media is working — media should NOT be on EFS
- Restart ECS tasks to refresh EFS mount

Long-term: if credits frequently deplete, consider EFS Provisioned Throughput.

---

## Step 2 — RDS Connection Pressure

```bash
# Check slow queries
mysql -h {rds_endpoint} -u admin -p -e "
  SELECT id, user, db, time, state, SUBSTRING(info,1,100)
  FROM information_schema.processlist
  WHERE time > 10 ORDER BY time DESC LIMIT 20;"

# Kill slow query by ID
mysql -h {rds_endpoint} -u admin -p -e "KILL QUERY {id};"
```

If many idle connections (command=Sleep, time>60): restart the affected client's ECS service to release connections.

---

## Step 3 — Valkey Cache Miss Storm (Post INC-004)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CacheHitRate \
  --period 60 --statistics Average \
  --start-time $(date -d '30 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)
```

**Hit rate < 50% AND auto-healer fired recently:** INC-004 pattern. Do NOT flush cache again. Wait 10-15 min for natural warmup. Check `AutoHealerActionsTaken` metric.

---

## Step 4 — ECS CPU Saturation

```bash
# Manually scale up if auto-scaling is slow to react
aws ecs update-service \
  --cluster wordpress-hosting-cluster \
  --service wordpress-{client}-svc \
  --desired-count 2
```

**CPU < 50% but latency high:** CPU is NOT the bottleneck. Check nginx logs for `worker_connections are not enough` (INC-005 pattern).

---

## Step 5 — Verify Resolution

```bash
# Watch p99 recover (run every 60 seconds)
watch -n 60 'aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=TargetGroup,Value={tg_arn_suffix} \
  --period 60 --extended-statistics p99 \
  --start-time $(date -d "5 minutes ago" -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)'
```

Target: p99 < 800ms within 10 minutes of fix applied.
