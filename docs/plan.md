# Project Plan — Build Phases and Progress

> A record of how the platform was designed and built, phase by phase. Written retrospectively to document what was built, what changed from the original plan, and why.

---

## Why document a plan retrospectively

The original plan changed many times during the build. Documenting the final version as if it was always the plan would be dishonest and less useful than documenting what actually happened — including the pivots, the restarts, and the decisions made after things broke.

---

## Phase 1 — VPC and Network Foundation

**Status:** Complete  
**Duration:** ~1 week

### What was built

The foundational AWS networking layer. Nothing runs in a flat network — all application resources run in private subnets with no direct internet access.

```
VPC: 10.0.0.0/16

Public subnets (AZ-a, AZ-b):    10.0.1.0/24, 10.0.2.0/24
  └── ALB
  └── NAT Gateway (one per AZ for HA)

Private subnets (AZ-a, AZ-b):   10.0.3.0/24, 10.0.4.0/24
  └── ECS Fargate tasks
  └── RDS (primary + standby)
  └── ElastiCache Valkey
```

Security groups follow the principle of least privilege:

| Resource | Allows inbound from | Allows outbound to |
|---|---|---|
| ALB | 0.0.0.0/0 on 443 | ECS SG on container port |
| ECS tasks | ALB SG only | RDS SG, Valkey SG, S3 via VPC endpoint, internet via NAT |
| RDS | ECS SG only | None |
| Valkey | ECS SG only | None |

### What changed from original plan

Originally planned to use a single NAT Gateway for cost reasons. Changed to one NAT Gateway per AZ after reading about the scenario where the single NAT Gateway's AZ has an outage — ECS tasks in the other AZ lose internet connectivity (for ECR image pulls and Secrets Manager calls) even though the AZ itself is healthy. The cost increase is ~$10/month. Worth it.

---

## Phase 2 — RDS and Data Layer

**Status:** Complete  
**Duration:** ~3 days

### What was built

RDS MySQL Multi-AZ instance (db.t3.micro). One database per client: `wp_clienta`, `wp_clientb`, `wp_clientc`. One MySQL user per client with `GRANT ALL PRIVILEGES ON wp_clientX.* TO 'clientX_user'@'%'` — user cannot access other client databases.

EFS with one access point per client. Each access point restricts the mounted path to `/wordpress-clientX` — a container mounting Client A's access point cannot navigate to Client B's directory.

Valkey cluster with per-client key prefix enforced via `WP_CACHE_KEY_SALT` in `wp-config.php`.

### What changed

Originally planned separate EFS file systems per client. Changed to one EFS with multiple access points after discovering that EFS access points provide the same path-level isolation at lower cost (no per-file-system charge) and simpler Terraform.

---

## Phase 3 — ECS and Application Layer

**Status:** Complete  
**Duration:** ~2 weeks (included the ClickOps elimination rebuild)

### What was built

Custom Docker image with WP-CLI, `entrypoint.sh`, Redis Object Cache plugin, and WP Offload Media plugin baked in. ECS Fargate cluster with one service per client. ALB with host-based routing rules directing traffic to the correct target group based on the HTTP Host header.

### The ClickOps elimination rebuild

Halfway through this phase, I realised the infrastructure had accumulated significant ClickOps — security group rules added manually, task definition tweaks made in the console, a CloudWatch alarm created through the UI. Terraform plan was showing false positives because the state no longer matched reality.

Decision: destroy the entire infrastructure and rebuild it from a clean Terraform state.

```bash
terraform destroy  # destroyed everything
# reviewed and cleaned up all Terraform files
terraform apply    # rebuilt from scratch
```

Full rebuild completed in approximately 12 minutes. The experience of rebuilding from scratch in 12 minutes was the most valuable validation of the IaC approach — it confirmed that the platform is genuinely reproducible.

---

## Phase 4 — S3 and CloudFront

**Status:** Complete  
**Duration:** ~4 days

### What was built

S3 bucket with per-client prefix policy. CloudFront distribution fronting both the ALB (for dynamic WordPress content) and S3 (for media). ACM certificates per client domain. Route 53 DNS records.

S3 media offload eliminates the highest-throughput EFS workload — WordPress media reads and writes go directly to S3 instead of EFS. This was added in response to Incident 4 (EFS burst credit exhaustion during load testing).

CloudFront achieves sub-100ms response times for cached static assets globally and reduces ALB origin requests by approximately 70% for returning visitors.

---

## Phase 5 — ECR and Custom Docker Image

**Status:** Complete  
**Duration:** ~1 week

### What was built

AWS ECR private repository. Multi-stage Dockerfile building a custom WordPress image with:

- WP-CLI installed for plugin management
- Redis Object Cache plugin pre-installed and configured
- WP Offload Media plugin pre-installed
- Custom `entrypoint.sh` for zero-touch configuration

The `entrypoint.sh` script:

1. Reads environment variables injected by Terraform
2. Generates `wp-config.php` with correct database, Valkey, and S3 configuration
3. Sets `WP_CACHE_KEY_SALT` from `CLIENT_ID` for cache namespace isolation
4. Runs WordPress database installation if this is a new site
5. Passes control to the WordPress FastCGI process

---

## Phase 6 — CI/CD Pipeline

**Status:** Complete  
**Duration:** ~1 week

### What was built

GitHub Actions workflow with four stages: PR validation (Checkov, hadolint, Trivy base scan, Terraform plan), Docker build, Trivy full scan + ECR push, ECS deployment matrix (three independent jobs, one per client).

OIDC credential federation — no static AWS access keys in GitHub Secrets. The workflow assumes an IAM role with a scoped permission set.

Auto-rollback Lambda triggered by CloudWatch alarm on post-deployment 5xx spike.

---

## Phase 7 — SRE Monitoring

**Status:** In progress  
**Duration:** Ongoing

### What has been built

- CloudWatch alarms (CRITICAL × 5, HIGH × 8, WARNING × 6)
- Log metric filters (4) with corresponding alarms
- Error budget Lambda (hourly, publishes `ErrorBudgetRemainingPercent` per client)
- Prometheus sidecar in ECS task definitions
- Recording rules (4) and alert rules (4)
- Three Grafana dashboards (Platform Overview, Per-Client Operational, SLO+FinOps)
- Structured JSON logging with `request_id` correlation
- Auto-healing Lambda (Level 3 — clears cache poisoning, kills hung queries)
- Deployment auto-rollback Lambda

### What is still in progress

- AWS Fault Injection Simulator chaos experiment (in progress)
- PagerDuty on-call integration (planned this week)
- Slack webhook rich notifications (planned this week)
- CloudWatch Synthetics Canary for external uptime monitoring (planned)
- X-Ray distributed tracing (planned)

---

## What I would do differently

**Start with the network design.** I spent time later refactoring security groups because the original design was too permissive. Drawing the security group chain (ALB → ECS → RDS → Valkey) before writing any Terraform would have saved that refactoring time.

**Run load tests earlier.** The EFS burst credit exhaustion (Incident 4) and RDS connection limit (Incident 5) were both discovered during dedicated load testing sessions. Running k6 against the platform from Phase 3 onward would have surfaced these issues earlier and influenced the architecture decisions (S3 media offload, RDS connection alarm) before they became incidents.

**Instrument from Phase 1.** Adding Prometheus and structured logging in Phase 7 means I have no historical metrics for the first six phases. An engineer working on a production system has metrics from day one. The retroactive instrumentation is correct but incomplete.

---

*Babu Lahade · Multi-Client WordPress Hosting Platform · 2025–2026*
