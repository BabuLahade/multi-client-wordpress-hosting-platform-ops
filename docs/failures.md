phase 2 504 gateway error i cant solved it 
i checke evrything network container port container logs container shell but all are okay my container is got timed out it cant connect to RDS 


RDS dabase connection error 502 target groups gave database error
password mismatch and credential mismatch
also endpoint mistamct instead endpoint use rda address 

302 error healthchecks of target group shown this 
solution added matcher = 200-309  bcz its normal bcz wordpresswnats to install it thas whya it gives you error 

# Failures, Incidents, and What I Learned

> This file documents real problems I hit while building and running this platform — configuration mistakes, architectural misunderstandings, things that broke unexpectedly. Writing them down is how I stop making the same mistake twice.

---

## Why this file exists

Every production system fails. The engineers who get better are the ones who write down what happened, why it happened, and what they changed. This is not a list of things that went wrong during a tutorial — these are things I actually broke and had to fix on a running system.

---

## Incident 1 — Cross-client cache collision from missing key prefix

**Date:** Early in Phase 3 development  
**Severity:** High — data integrity issue  
**Duration:** Discovered during testing, not in production  

### What happened

I deployed Client A and Client B using the same Valkey cluster. WordPress object cache was working. Then I noticed Client B's homepage was occasionally showing Client A's cached post content. 

At first I thought it was a browser cache issue. Then I cleared the browser cache and reproduced it consistently by hitting the API directly.

### Root cause

The Redis Object Cache plugin uses WordPress site URL as part of its cache key prefix by default. Both sites were running on ALB DNS hostnames during development (`internal-alb-xxx.ap-south-1.elb.amazonaws.com`) — identical hostnames. Both sites wrote to the same Valkey keyspace with colliding keys.

```
# Client A cache key
wp:clienta.com:posts:1234  → expected behaviour

# During development, both sites resolved to the same internal hostname
wp:internal-alb.elb.amazonaws.com:posts:1234  → collision
```

### What I changed

Explicitly set the `WP_CACHE_KEY_SALT` constant per client in `entrypoint.sh`, derived from the `CLIENT_ID` environment variable. This makes cache keys unique regardless of hostname.

```bash
# entrypoint.sh — added this line
echo "define('WP_CACHE_KEY_SALT', '${CLIENT_ID}_');" >> /var/www/html/wp-config.php
```

Added a contract test that writes a key for Client A and verifies Client B cannot read it. This test now runs in the staging CI/CD pipeline on every deployment.

### What I learned

Shared infrastructure isolation requires explicit configuration at every layer. Relying on implicit defaults (like plugin-generated cache keys) is a reliability risk in multi-tenant systems. Every shared resource needs explicit namespacing, not assumed namespacing.

---

## Incident 2 — ECS tasks failing health checks after new deployment

**Date:** During Phase 6 (CI/CD pipeline setup)  
**Severity:** Critical — all three client sites unreachable for ~8 minutes  
**Duration:** 8 minutes from deploy to recovery  

### What happened

I pushed a new Docker image and the CI/CD pipeline ran successfully — Trivy passed, image built, ECR push succeeded, ECS update-service triggered. Then all three client sites went down. The ALB was returning 502 for all requests.

Looking at the ECS service events: new tasks were starting, running the health check on `/health.php`, and failing immediately. The old tasks had already been stopped (they were draining connections). So all targets in all three target groups were failing the ALB health check simultaneously.

### Root cause

The `minimumHealthyPercent` in the ECS deployment configuration was set to `0`. This meant ECS would stop all old tasks immediately when the rolling update started, before confirming new tasks were healthy. The new tasks were failing because `/health.php` was checking Valkey connectivity, and Valkey was refusing connections — I had rotated the Valkey auth token but only updated Secrets Manager, not the ECS task environment variable that was cached from the previous deployment.

Two separate mistakes combined into one outage:

1. `minimumHealthyPercent = 0` allowed stopping healthy tasks before new ones were verified
2. Secrets Manager rotation did not trigger an ECS task definition update

### What I changed

Set `minimumHealthyPercent = 100` in the ECS service deployment configuration. This forces the rolling update to start new tasks first, wait for them to pass health checks, and only then stop old tasks. The platform runs at double capacity for 60–90 seconds during deployments — a small cost increase that is worth the zero-downtime guarantee.

Added a Terraform output that checks Secrets Manager version against the ECS task definition environment variable hash. If they diverge, the pipeline fails before deployment.

Documented this as the reason `minimumHealthyPercent` must always be `100` in [`docs/adr/006-ecs-deployment-config.md`](docs/adr/006-ecs-deployment-config.md).

### What I learned

Deployment configuration defaults are not safe. `minimumHealthyPercent = 0` is ECS's default because it is the cheapest option — no double capacity during updates. But for a production platform, zero-downtime deployment is a requirement, not a preference. Default settings in managed services are optimised for cost, not reliability. Always check them explicitly.

---

## Incident 3 — Terraform state lock preventing production deployment

**Date:** During Phase 5 (IaC cleanup after ClickOps elimination)  
**Severity:** Medium — no client impact, but blocked planned maintenance window  
**Duration:** 45 minutes to resolve  

### What happened

I ran `terraform destroy` on a development version of the platform (to rebuild from scratch and eliminate all ClickOps). The destroy completed successfully. Then I ran `terraform apply` to build the clean version. It failed immediately:

```
Error: Error acquiring the state lock
Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID: 9b3f2a1c-...
  Operation: OperationTypeApply
  Who: dev@laptop
  Created: 2025-XX-XX (12 minutes ago)
```

The DynamoDB state lock from the previous `terraform apply` had not been released — the process had been interrupted mid-operation and the lock record was orphaned.

### Root cause

I had run `terraform apply` from my laptop, lost wifi connectivity mid-apply, and the process was interrupted without releasing the lock. Terraform writes a lock record to DynamoDB at the start of every operation and deletes it at the end. An interrupted operation does not clean up the lock.

### How I resolved it

Checked that no other apply was actually running (it was not — this was a stale lock). Manually deleted the lock record from DynamoDB:

```bash
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "wordpress-platform/terraform.tfstate-md5"}}'
```

Then re-ran `terraform apply`.

### What I changed

Added a note to the project README about interrupted Terraform operations. Added a CI/CD check that verifies no stale lock exists before running `terraform apply` in the pipeline. Never run `terraform apply` from a laptop on unstable connections — all infrastructure changes go through the CI/CD pipeline.

### What I learned

Remote state locking protects against concurrent operations but creates a new failure mode: orphaned locks. The resolution is straightforward but requires manual intervention. The prevention is to always run Terraform from a stable CI/CD environment, not a local machine. This is one of the reasons I moved all infrastructure changes to GitHub Actions.

---

## Incident 4 — EFS burst credit exhaustion causing WordPress slowness

**Date:** During load testing Phase  
**Severity:** High — all three clients affected, 8–10 second page loads  
**Duration:** ~2 hours before identified and mitigated  

### What happened

During k6 load testing at 500 concurrent users per client, page load times started at 600ms p99 and gradually climbed to 8–10 seconds over the course of 90 minutes. The k6 test was still running at full load. CloudWatch showed ECS CPU and memory were normal. RDS CPU was elevated but not critical. The ALB showed high `TargetResponseTime` with no increase in error rate.

I could not immediately identify the cause because all ECS, RDS, and Valkey metrics looked healthy.

### Root cause

EFS on the Standard storage class uses a burst credit system. Credits accumulate when I/O is below the baseline (50MB/s per TB stored) and are consumed when I/O exceeds the baseline. With a small amount of data stored (WordPress files, themes, plugins — maybe 2GB), the baseline throughput is approximately 100KB/s. The burst credit balance was healthy at the start of the load test and was fully consumed within 90 minutes of sustained high-throughput reads.

Once credits hit zero, EFS I/O was limited to 100KB/s for all three clients combined. Every WordPress page load reads theme files, plugin files, and uploads from EFS. At 100KB/s for 1500 concurrent users, every file read was queuing.

I did not have a CloudWatch alarm on `BurstCreditBalance` when this happened.

### What I changed

Added a CloudWatch alarm on EFS `BurstCreditBalance` with a WARNING threshold at 1,000,000 credits — before depletion, with time to act.

Implemented S3 media offload using WP Offload Media plugin (baked into the Docker image via WP-CLI). WordPress media uploads now go directly to S3 and are served via CloudFront. This removes the highest-throughput EFS workload entirely and reduces EFS usage to static files (themes, plugins) which have much lower read rates.

Added the EFS burst credit alarm and the S3 media offload status to the Grafana platform overview dashboard.

### What I learned

EFS burst credits are a hidden performance cliff. The `BurstCreditBalance` metric declining toward zero is a warning that is invisible until it is too late — unless you are specifically monitoring for it. Static file reads are not obviously a bottleneck until you multiply them by several hundred concurrent users simultaneously. Understanding the infrastructure's performance limits (not just failure modes) is part of SRE work.

---

## Incident 5 — RDS `max_connections` limit hit during testing

**Date:** During SRE monitoring setup  
**Severity:** Critical — all WordPress sites returned DB connection errors  
**Duration:** 4 minutes  

### What happened

While stress-testing the monitoring setup, I ran k6 against all three client sites simultaneously at high concurrency. After about 3 minutes, all three sites started returning "Error establishing a database connection." The WordPress white screen of death, simultaneously, across all clients.

### Root cause

db.t3.micro has a `max_connections` value of approximately 100. Each ECS task for each client maintains a PHP-FPM process pool with multiple workers, each holding a database connection. Under high concurrency:

- 3 clients × 3 tasks per client (auto-scaled) × 8–10 PHP-FPM workers per task = 72–90 connections

Under load, PHP-FPM was spinning up additional workers which pushed the total past 100. When the 101st connection attempt was made, MySQL rejected it with `Too many connections`, which WordPress reports as "Error establishing a database connection."

### What I changed

Added a CloudWatch alarm on `DatabaseConnections` with a HIGH threshold at 85 connections — before the limit, with time to act.

Documented the single shared RDS instance as a known architecture limitation in the README and in [`docs/adr/007-rds-connection-limits.md`](docs/adr/007-rds-connection-limits.md). The mitigation path at scale is RDS Proxy, which pools connections between ECS tasks and RDS and can reduce the actual database connection count significantly.

Reduced PHP-FPM `pm.max_children` in the Docker image configuration to limit connections per task.

### What I learned

Shared infrastructure creates coupled failure modes. In a fully isolated architecture, Client A's database connection exhaustion cannot affect Client B. On a shared RDS instance, it can. The architecture decision to share RDS was made for cost reasons and is the right decision for a three-client platform — but it comes with this failure mode, which must be monitored and documented. Architectural trade-offs are only safe when they are explicit.

---

## Incident 6 — GitHub Actions deploying ClickOps infrastructure

**Date:** Mid-project (before the full IaC rebuild)  
**Severity:** Low — no client impact, but significant future risk  
**Duration:** Discovered during code review, not during an incident  

### What happened

Not a production incident — a design problem I caught before it caused one. I was reviewing the Terraform state and noticed that some ECS service configuration was not matching what was in the Terraform files. I could not explain the difference.

Investigation revealed that I had made several changes directly in the AWS console during development — modified an ECS task definition, changed a security group rule, added a CloudWatch alarm manually. Terraform's state file reflected what it had last applied, not what was actually running in AWS.

This meant the CI/CD pipeline was deploying code on top of manually modified infrastructure. Any `terraform apply` would have reverted my console changes. Any console change I made would be invisible to Terraform.

### Root cause

Console access during development. Every time something was not working as expected, it was faster to fix it in the console than to figure out the correct Terraform syntax. Over time, the console changes accumulated and diverged from the IaC.

### What I changed

Destroyed the entire infrastructure and rebuilt it from Terraform from scratch. This was uncomfortable — a full destroy of a running platform — but it was the only way to guarantee that Terraform state matched reality.

Added SCPs (Service Control Policies) to restrict console resource modification on the production account. All infrastructure changes must go through the CI/CD pipeline.

Added Checkov IaC scanning to the PR validation pipeline to catch insecure or misconfigured Terraform before it is applied.

Documented the ClickOps elimination as a specific milestone in the project — the moment the platform became genuinely reproducible.

### What I learned

A platform that cannot be fully reproduced from code is not infrastructure as code — it is infrastructure with code commentary. The discipline required is not technical, it is habitual: every change goes through Terraform, no exceptions. The discomfort of the full rebuild was worth it because after it, I was completely confident that `terraform apply` on a blank account would produce exactly the running platform.

---

## Recurring patterns

Reading through these incidents, three patterns keep appearing:

**1. Implicit defaults are not safe defaults.**  
`minimumHealthyPercent = 0`, missing cache key prefixes, EFS burst credits — all were default behaviours that were acceptable in isolation and dangerous in production. Explicit configuration at every layer, even for things that "just work."

**2. Monitoring gaps are future incident reports.**  
The EFS burst credit incident and the RDS connection incident both had leading indicators that I was not monitoring. The alarm on `BurstCreditBalance` and `DatabaseConnections` that I added after the fact should have existed before the first load test. Build the monitoring before you need it.

**3. Write down the trade-offs.**  
Shared RDS, single-node Valkey, file-based sessions — these are all conscious cost-driven decisions that come with specific failure modes. Documenting them in ADRs means the failure mode is not a surprise when it appears. It is an expected behaviour of a known trade-off.

---

*Last updated: April 2026*


in grfana all dropdown not working we try it but didnt worked we also tried regex not working single client works but wildcard entry is not worked

Incident: CloudWatch multi-tenant variable filtering failure
Duration: 2 days of debugging
Root cause: CloudWatch MetricStat does not support multi-value dimension filtering. Passing a Grafana variable containing multiple client names results in either empty data (curly-brace format rejected) or a single aggregated series (wildcard format merges all clients).
What I tried: Custom all value = *, Metric Insights SQL IN clause, *wildcard* with Match Exact OFF, regex patterns.
What worked: Grafana Panel Repeat feature — one panel template repeated per variable value, each panel using wordpress-hosting-${client_id}-service as an exact dimension match for its specific client.
What I learned: CloudWatch is a dimension-exact metric system, not a label-based system like Prometheus. Prometheus lets you filter and group by labels flexibly. CloudWatch requires you to know exactly which dimension values you want at query time. Design your observability architecture around this constraint — per-metric queries per tenant, not variable filtering across tenants.


###### Grafana ai used for solve above 
✅ **All 6 panels are running.** Here's the status:  

| Panel | Status | Notes |  
|-------|--------|-------|  
| ECS CPU Utilization | ✅ Data | client3: 56.3% max, client4: 55.7%, client5: 63.2% |  
| ECS Memory Utilization | ✅ Data | client3: 14.9%, client4: 17.9%, client5: 18.6% |  
| ECS Running Task Count | ✅ Data | Historical spikes visible, currently 0 tasks |  
| ALB Response Time | ⚪ No data | No ALB traffic in last 2 days — not a bug |  
| ALB Error Count | ⚪ No data | Same reason — no traffic |  
| ALB Healthy/Unhealthy Hosts | ⚪ No data | Same reason — no traffic |  

**Why ALB shows "No data":** Your ALB target groups exist, but there's been no incoming HTTP traffic to generate CloudWatch metrics in the last 2 days. The moment traffic flows through the ALB, these panels will show data automatically.  

---  

## 📖 Self-Help Guide — Adding CloudWatch Panels to This Dashboard  

### 1. How the Variable Cascade Works  

```  
client_id (you pick: client3 / client4 / client5 / All)  
    │  
    ├─► ecs_service  (HIDDEN — auto-filters ECS service names)  
    │   regex: (wordpress-hosting-(?:${client_id:regex})-service)  
    │  
    └─► alb_tg       (HIDDEN — auto-filters ALB target groups)  
        regex: (targetgroup/(?:${client_id:regex})[^/]*/[a-f0-9]+)  
```  

**Rule:** Never expose `ecs_service` or `alb_tg` in the UI dropdown. They are hidden cascade variables — changing `client_id` automatically updates them.  

---  

### 2. Two Query Types in CloudWatch  

#### Type A — MetricStat (use for ECS)  
Works when you have **1 specific dimension value** or when the variable expands to `{val1,val2,val3}`:  

```  
Namespace:  AWS/ECS  
Metric:     CPUUtilization  
Dimensions: ClusterName = wordpress-hosting-cluster  
            ServiceName = ${ecs_service}  
matchExact: false   ← important! allows multi-value expansion  
```  

✅ Use MetricStat for: `CPUUtilization`, `MemoryUtilization`, `RunningTaskCount`  

#### Type B — Metric Insights SQL (use for ALB)  
Required when MetricStat can't handle `$__all` expansion. Uses SQL syntax:  

```sql  
SELECT AVG(TargetResponseTime)  
FROM SCHEMA("AWS/ApplicationELB", TargetGroup, LoadBalancer)  
WHERE TargetGroup LIKE 'targetgroup/client_-tg-%'  
GROUP BY TargetGroup  
LIMIT 10  
```  

The `_` in `client_` is a SQL wildcard = any single character → matches client**3**, client**4**, client**5**.  

✅ Use SQL for: all `AWS/ApplicationELB` metrics — `TargetResponseTime`, `HTTPCode_Target_5XX_Count`, `RequestCount`, `HealthyHostCount`  

---  

### 3. Adding a New ECS Panel (Step-by-Step)  

1. Click **Add panel** → **Add visualization**  
2. Select datasource: **CloudWatch (efj11a9nphcsga)**  
3. Switch to **Code editor** mode  
4. Set:  
   - Query type: `CloudWatch Metrics`  
   - Namespace: `AWS/ECS`  
   - Metric name: *(e.g. CPUReservation)*  
   - Dimensions: `ClusterName = wordpress-hosting-cluster`, `ServiceName = ${ecs_service}`  
   - Statistic: `Average`  
   - Region: `eu-north-1`  
   - Label: `${PROP('Dim.ServiceName')}`  
   - **matchExact = false**  

---  

### 4. Adding a New ALB Panel (Step-by-Step)  

1. Click **Add panel** → **Add visualization**  
2. Select datasource: **CloudWatch**  
3. In the query builder, switch to **Code / SQL** mode  
4. Set `metricQueryType = 1` (Metric Insights)  
5. Write your SQL:  

```sql  
SELECT SUM(RequestCount)  
FROM SCHEMA("AWS/ApplicationELB", TargetGroup, LoadBalancer)  
WHERE TargetGroup LIKE 'targetgroup/client_-tg-%'  
GROUP BY TargetGroup  
ORDER BY SUM(RequestCount) DESC  
LIMIT 10  
```  

6. Region: `eu-north-1`  
7. Panel type: **Time series**  

---  

### 5. Common Mistakes to Avoid  

| Mistake | Fix |  
|---------|-----|  
| ALB panel shows "No data" with MetricStat | Switch to Metric Insights SQL |  
| Variable shows only client3 | Check for stale `current` state — use `set` operation to redefine the variable |  
| ECS multi-service not showing | Add `matchExact: false` to the query |  
| Wrong region | Always set `eu-north-1` explicitly (don't use "default") |  
| `$ecs_service` not expanding | Make sure `var-ecs_service=$__all` is in the URL |  

---  

### 6. Available Metrics Reference  

**ECS (`AWS/ECS`)**  
- `CPUUtilization` — % CPU used per service  
- `MemoryUtilization` — % memory used per service  

**ECS Container Insights (`ECS/ContainerInsights`)**  
- `RunningTaskCount` — number of running tasks  
- `DesiredTaskCount`, `PendingTaskCount`  

**ALB (`AWS/ApplicationELB`)**  
- `TargetResponseTime` — latency in seconds (use p99/p95/p50)  
- `RequestCount` — total requests  
- `HTTPCode_Target_5XX_Count` — server errors  
- `HTTPCode_Target_4XX_Count` — client errors  
- `HealthyHostCount` / `UnHealthyHostCount`

## Incident: ALB 5XX vs Target 5XX Misleading Metrics

### What happened
Set ECS desired count = 0 → all targets deregistered

### Observation
- TargetGroup metrics showed 0 errors ❌ (misleading)
- ALB metrics showed 5XX errors ✔ (real issue)

### Root Cause
No registered targets → ALB itself returned 5XX

### Learning
Target-level metrics only work when targets exist.

### Fix
Added:
- ELB error rate monitoring
- HealthyHostCount alarm
- Dual-layer monitoring (ELB + Target)

### client level slo will not affect but its actullyaffecting by downtime its like blind spot or hole in or slo and error rate  

###########################################
CLAUDE 
###########################################

# FAILURES.md — Production Incident Log

> Real failures discovered during development, load testing, and chaos engineering.
> A project without a FAILURES.md was never tested or hid its failures.

| # | Title | Severity | Status |
|---|-------|----------|--------|
| INC-001 | ECS deployment caused 8-minute complete outage | CRITICAL | ✅ Fixed |
| INC-002 | EFS burst credit exhaustion — pages degraded to 8-10s | HIGH | ✅ Fixed |
| INC-003 | SLO Lambda reported 100% uptime during 4-minute real outage | CRITICAL | ✅ Fixed |
| INC-004 | Auto-healer caused cache stampede — DB connections 20→40 | HIGH | ✅ Fixed |
| INC-005 | Nginx worker exhaustion — 1,100 VUs caused 78% failure rate | HIGH | ⏳ v2.0 planned |
| INC-006 | ClickOps drift — Terraform state diverged from AWS reality | MEDIUM | ✅ Fixed |

---

## INC-001 — ECS Deployment Caused 8-Minute Complete Outage

**Severity:** CRITICAL | **Clients affected:** All 3 simultaneously

### What Happened
During a routine Docker image deployment, all three client sites went offline for 8 minutes. Every user received 503 Service Unavailable.

### Root Cause
ECS default `minimumHealthyPercent = 0` allows ECS to stop ALL old tasks before new tasks are healthy. New tasks failed initial health checks (WordPress DB connection warmup takes 20-30 seconds). Zero tasks running → zero ALB healthy targets → 503 for 8 minutes.

```
T+00:00  terraform apply → new ECS task definition
T+00:20  ECS stops ALL old tasks immediately (minimumHealthyPercent=0 default)
T+00:21  New tasks starting — health check not yet passing
T+00:21  ALB: zero healthy targets → returns 503 to all users
T+08:00  New tasks pass health check → sites restored
```

### Fix
```hcl
resource "aws_ecs_service" "wordpress" {
  deployment_minimum_healthy_percent = 100  # was 0 — start new before stopping old
  deployment_maximum_percent         = 200  # allow double capacity during deploy
  health_check_grace_period_seconds  = 60   # give WordPress time to start up
}
```

### Lesson
Never trust infrastructure defaults for production. `minimumHealthyPercent = 0` is catastrophic for always-on web hosting. Every ECS deployment parameter must be explicitly reviewed.

---

## INC-002 — EFS Burst Credit Exhaustion — Progressive Slowdown to 8-10s

**Severity:** HIGH | **Duration:** 90-minute gradual degradation | **Clients affected:** All 3

### What Happened
During load testing, page load times climbed gradually from 600ms to 8-10 seconds over 90 minutes. ECS, RDS, and Valkey all appeared healthy in CloudWatch. Monitoring was completely blind to this failure.

### Root Cause
Amazon EFS uses a burst credit system. Credits allow 100MB/s throughput. Exhaustion drops throughput to 50KB/s baseline. WordPress makes 200-400 PHP file reads per page request. Under sustained load, burst credits depleted over 90 minutes causing 2000x slower I/O with no errors.

```
T+00:00  Load test begins — p99 600ms normal
T+30:00  Credits depleting — p99 climbing to 1.2s
T+60:00  Credits at 30% — p99 now 4s
T+90:00  Credits at 2% — p99 now 8-10s
         ECS: healthy ✓  RDS: healthy ✓  Valkey: healthy ✓
         BurstCreditBalance: never monitored ← the blind spot
```

### Fix
- CloudWatch WARNING alarm: `EFS BurstCreditBalance < 1,000,000`
- S3 Offload Media implemented — media now goes to S3 via VPC endpoint, removing highest-throughput workload from EFS
- S3 VPC endpoint added — traffic stays within AWS network, no NAT Gateway transit cost

```
Before: EFS handles themes + plugins + media (all I/O on one filesystem)
After:  EFS handles themes + plugins only (read-heavy, burst-friendly)
        S3 via VPC endpoint handles media (large files, no EFS impact)
```

### Lesson
Performance degradation does not always produce errors. A system can pass all health checks while delivering terrible user experience. Hidden infrastructure limits require monitoring resource-specific capacity metrics, not just error rates.

---

## INC-003 — SLO Lambda Reported 100% Uptime During 4-Minute Real Outage

**Severity:** CRITICAL | **Duration:** 4 minutes undetected | **Clients affected:** clienta

### What Happened
Phase 1 load test with 1 ECS task: k6 showed **16.6% failure rate** (1,168 failed requests) and 4 minutes of 5xx errors. The SLO Lambda simultaneously reported **100% availability** and **0% error budget consumed**.

The platform was down. The SLO said it was perfect.

### Root Cause
SLO Lambda measured `HTTPCode_Target_5XX_Count` at TargetGroup dimension. When the ECS task crashed and deregistered, the target group had zero registered targets. Zero targets = CloudWatch receives NO DATA. Lambda treated "no data = no errors" → calculated 100% availability.

Meanwhile the ALB was returning 502 "No healthy targets" — recorded in `HTTPCode_ELB_5XX_Count` (ALB-level metric) which the Lambda never checked.

```
Reality:
  Users → ALB → "No healthy targets" → 502 → user
                ↓ recorded in HTTPCode_ELB_5XX_Count  ← NEVER MONITORED
                ↓ NOT in HTTPCode_Target_5XX_Count     ← WAS MONITORED

Lambda calculation:
  HTTPCode_Target_5XX_Count = 0 (no targets to generate errors)
  availability = (requests - 0) / requests = 100%  ← WRONG
```

### Fix
```python
# BEFORE — WRONG
MetricName = 'HTTPCode_Target_5XX_Count'
Dimensions = [{'Name': 'TargetGroup', 'Value': tg_arn}]

# AFTER — CORRECT
MetricName = 'HTTPCode_ELB_5XX_Count'      # ALB level — always reports
Dimensions = [{'Name': 'LoadBalancer', 'Value': alb_arn_suffix}]
```

Three new CRITICAL alarms added with `treat_missing_data = breaching`:
- `RunningTaskCount = 0` per client ECS service (fires first — ECS layer)
- `HealthyHostCount = 0` per client target group (ALB layer)
- `HTTPCode_ELB_5XX_Count > 3` at ALB level (user impact confirmation)

### Lesson
Monitoring must be validated by deliberately causing the failure it is meant to detect. `treat_missing_data = missing` (CloudWatch default = OK) is wrong for health metrics. For HealthyHostCount and RunningTaskCount — no data means the healthy thing is gone. That is ALARM, not OK.

---

## INC-004 — Auto-Healer Caused Cache Stampede — DB Connections Spiked 20→40

**Severity:** HIGH | **Duration:** 15 minutes | **Clients affected:** clienta

### What Happened
High response times during Phase 1 load test triggered the Tier 3 Auto-Healer Lambda. Lambda found no locked queries, executed fallback FLUSHALL on Valkey. All 200 concurrent users got simultaneous cache misses, forcing every PHP worker to hit RDS directly. DB connections spiked 20→40. More latency → Lambda re-triggered → flushed cache again. Loop repeated **8 times in 15 minutes**.

```
T+02:00  High latency → Lambda fires (attempt 1)
T+02:05  Lambda: SHOW PROCESSLIST → no locked queries found
T+02:06  Lambda: FLUSHALL (fallback action) ← THE MISTAKE
T+02:07  200 users: cache miss → all hit RDS simultaneously
T+02:08  DB connections: 20 → 40
T+02:10  More latency → Lambda fires again (attempt 2)
         ... loop × 8 total
T+17:00  Lambda concurrency limit reached — loop breaks naturally
```

### Root Cause
```python
# ORIGINAL LOGIC — WRONG
def heal():
    killed = kill_locked_queries()
    if not killed:
        flush_valkey_cache()  # ran even when no locked queries existed — WRONG
```

Cache flush was unconditional — ran whenever latency was high and no locked queries were found. This is the wrong logic. High latency caused by load (not cache poisoning) triggered cache flush which caused more load in a feedback loop.

### Fix
```python
# FIXED LOGIC
def heal():
    locked_queries = find_locked_queries()
    if not locked_queries:
        logger.info("No locked queries. Latency is load-based. No action taken.")
        return  # ← do nothing when no confirmed diagnosis
    killed = kill_locked_queries(locked_queries)
    if killed > 0:
        flush_affected_cache_keys(locked_queries)  # targeted flush, not FLUSHALL
```

Lambda reserved concurrency set to 1 per client — prevents parallel execution loops.

### Lesson
Automated remediation can cause more damage than the failure it responds to. Every healing action must be conditional on confirmed diagnosis. When uncertain about root cause, do nothing and alert a human. Automation must fail safe.

---

## INC-005 — Nginx Worker Exhaustion Under 1,100 Concurrent Users

**Severity:** HIGH | **Phase:** Load Test Phase 2 (Noisy Neighbor) | **Status:** v2.0 fix planned

### What Happened
Phase 2: 1,100 concurrent VUs directed at clienta. clienta failed at **78.42%** (5,477 failed requests, avg 41s response). clientb maintained **100% success rate** throughout. ECS CPU for clienta stayed at 45% — auto-scaler never triggered.

### k6 Test Data
```
Phase 2 — clienta (target of 1,100 VUs):
  http_req_failed:   78.42% (5,477/6,983)
  http_req_duration: avg=41s  p95=55s
  errors:            504 Gateway Timeout, 499 Client Closed Request

Phase 2 — clientb (bystander — 500 VUs):
  http_req_failed:   0.00% (0/500)   ← complete isolation confirmed ✓
  http_req_duration: avg=390ms  p99=680ms

clienta ECS CPU: 45%  (NOT saturated — auto-scaler never triggered)
```

### Root Cause
CloudWatch Logs Insights on nginx error logs revealed:
```
[alert] 20#20: 1024 worker_connections are not enough
```

Nginx default `worker_connections = 1024`. With 0.25 vCPU Fargate (1 worker process), the container accepted exactly 1,024 connections and **immediately dropped all remaining**. Dropped connections returned 504 before reaching PHP. Because PHP was never called, CPU stayed low. Because CPU stayed low, ECS auto-scaler never triggered.

```
1,100 users → Nginx
               ↓ 1,024 connections accepted → PHP-FPM → normal
               ↓ 76 connections dropped → 504 to user instantly
               CPU: 45% (PHP never processed dropped connections)
               Auto-scaler: watching CPU — never fired
```

### v2.0 Fix
```nginx
# nginx.conf — next Docker image build
events {
    worker_connections 4096;  # was 1024 — 4x capacity
    use epoll;
    multi_accept on;
}
```
Plus: CloudFront + WAF in front of ALB to absorb edge traffic before hitting containers.

### What Phase 2 Proved ✅
**Tenant isolation held completely.** clientb was 100% unaffected during the 1,100 VU assault. Shared RDS peak connections: 38 (normal). VPC, security groups, and separate target groups fully contained the blast radius. One client dying does not affect others.

### Lesson
Auto-scaling cannot protect against limits that exist below the metric the auto-scaler is watching. Every layer has a capacity ceiling — Nginx connections, EFS burst credits, RDS connections. Each must be monitored explicitly.

---

## INC-006 — ClickOps Drift: Terraform State Diverged from AWS Reality

**Severity:** MEDIUM | **Clients affected:** None (caught before production)

### What Happened
Manual AWS Console changes during development accumulated over several weeks. `terraform plan` showed 23 resources to be destroyed and recreated — including ECS services and the RDS instance. Running `terraform apply` would have caused a major production outage.

### Root Cause
Changes made outside Terraform create state drift. Terraform reconciles by reverting manual changes to match code — destroying and recreating resources that differ from the state file.

### Fix
1. Documented all manual changes before destruction
2. `terraform destroy` on drifted resources
3. All changes codified in Terraform
4. `terraform apply` from clean state — **full rebuild: 11 minutes 43 seconds**

Added `terraform plan` as mandatory CI check on all PRs — drift detected at PR stage before merging.

### Lesson
ClickOps is not just inconvenient — it is dangerous. When Terraform is the only source of truth, you can destroy everything and rebuild in 12 minutes. When the Console is also a source of truth, you cannot trust either.

---
*Last updated: April 2026 | Babu Lahade*
