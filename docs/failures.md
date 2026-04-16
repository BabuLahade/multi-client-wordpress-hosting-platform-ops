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