# Development and Deployment Workflow

> How code moves from a local change to running in production. How infrastructure changes are made. What happens automatically and what requires a human decision.

---

## Core principle

Every change to this platform goes through version control. No exceptions. A change that cannot be described in a git commit is a change that should not be made.

This means:

- Application changes → Docker image rebuild → ECS rolling deploy
- Infrastructure changes → Terraform plan review → Terraform apply via CI/CD
- Configuration changes → environment variable update in Terraform → ECS task definition update → ECS rolling deploy
- Secrets rotation → Secrets Manager update → ECS task restart (entrypoint.sh re-reads at boot)

If you are in the AWS console changing something, stop. Write it in Terraform first.

---

## Branch strategy

```
main              ← production (protected, requires PR approval)
feature/*         ← new features
fix/*             ← bug fixes
infra/*           ← Terraform changes
```

Direct pushes to `main` are blocked. All changes go through a pull request with at least one approved review before merge.

---

## Pull request workflow

### What happens automatically when you open a PR

Four checks run in parallel on every PR, triggered by `.github/workflows/pr-validation.yml`:

```
PR opened or updated
        │
        ├── Checkov IaC scan
        │   Scans terraform/ directory for security misconfigurations
        │   Fails on: open security groups, unencrypted RDS, public S3 buckets
        │   Runtime: ~45 seconds
        │
        ├── hadolint Dockerfile lint
        │   Checks Dockerfile for best practices
        │   Fails on: using :latest tags, running as root, curl | bash patterns
        │   Runtime: ~10 seconds
        │
        ├── Trivy base layer scan
        │   Scans the base WordPress image layer only (not full build — for speed)
        │   Fails on: HIGH or CRITICAL CVEs in base image packages
        │   Runtime: ~60 seconds
        │
        └── Terraform plan
            Runs terraform plan and posts the output as a PR comment
            Does NOT apply — shows what would change
            Requires: read-only IAM role via OIDC (cannot modify anything)
            Runtime: ~90 seconds
```

All four checks must be green before the PR can be merged.

### What you review in the PR

- Terraform plan output posted as a comment — review what infrastructure will change
- Checkov output if it flagged anything — either fix the issue or add an explicit override with justification
- Trivy findings if any appeared — update the base image or accept and document the risk

---

## Merge to main — deployment pipeline

When a PR merges to `main`, `.github/workflows/deploy.yml` runs automatically:

```
merge to main
      │
      ▼
Step 1: Configure AWS credentials
      GitHub Actions assumes IAM role via OIDC
      Short-lived token (15 minutes), no static access keys
      Role has: ECR push, ECS update-service, read Secrets Manager
      │
      ▼
Step 2: Build Docker image
      docker build -t $ECR_REGISTRY/wordpress-platform:$GITHUB_SHA .
      Tagged with Git commit SHA — every image traceable to its source commit
      │
      ▼
Step 3: Trivy full image scan
      trivy image --exit-code 1 --severity HIGH,CRITICAL
      Scans the fully built image, not just the base layer
      Also runs filesystem scan for accidentally embedded secrets
      ── FAIL: pipeline stops here, image never reaches ECR ──
      │
      ▼
Step 4: Push to ECR
      docker push $ECR_REGISTRY/wordpress-platform:$GITHUB_SHA
      Image is immutable — SHA tag cannot be overwritten
      │
      ▼
Step 5: Deploy to ECS (matrix — 3 parallel jobs)
      ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
      │  Client A   │  │  Client B   │  │  Client C   │
      │  deploy job │  │  deploy job │  │  deploy job │
      └─────────────┘  └─────────────┘  └─────────────┘
      
      Each job:
      1. Registers new ECS task definition with commit SHA image tag
      2. Calls aws ecs update-service (minimumHealthyPercent=100)
      3. Waits for service to reach stable state (new task healthy, old task stopped)
      4. If service does not stabilise in 10 minutes: job fails
      
      fail-fast: false — Client A failure does NOT stop Client B or Client C
      │
      ▼
Step 6: Post-deployment monitoring (automatic)
      CloudWatch alarm monitors 5xx error rate per client for 10 minutes
      If error rate > 2%: auto-rollback Lambda triggers
      Rollback reverts to previous ECS task definition revision
      Slack notification sent: "AUTO-ROLLBACK: clienta — reason: 5xx spike"
```

**Total pipeline time:** approximately 6–8 minutes from merge to all three clients updated.

---

## Infrastructure change workflow

Infrastructure changes (Terraform) follow the same PR → review → merge process. The difference is what gets reviewed.

### Adding a new client

1. Add one block to `terraform/environments/production/terraform.tfvars`
2. Open a PR
3. Terraform plan runs automatically and posts what will be created (new ECS service, task definition, ALB target group and rule, RDS database and user, EFS access point, Valkey key prefix, CloudWatch alarms, Secrets Manager secret, Route 53 record, ACM certificate)
4. Review the plan — does it match what you intended?
5. Merge → `terraform apply` runs in CI/CD
6. New client is live in approximately 10 minutes

### Modifying existing infrastructure

Same flow. The Terraform plan shows exact diffs — what will be changed, replaced, or destroyed. Pay particular attention to:

- **`must be replaced`** — resource will be destroyed and recreated. For ECS task definitions, this is expected. For RDS instances, this causes downtime unless Multi-AZ failover handles it.
- **`will be updated in-place`** — safe, no downtime
- **`will be destroyed`** — review carefully before merging

### Never run `terraform apply` from your laptop

All Terraform applies go through the CI/CD pipeline. Running from a laptop creates two risks:

1. State drift — your local state file may be stale
2. No review gate — changes are applied without a PR review

The only exception is emergency rollback, documented in [`docs/runbooks/disaster-recovery.md`](docs/runbooks/disaster-recovery.md).

---

## Adding a new alarm

Alarms are defined in `terraform/modules/monitoring/main.tf`. To add a new alarm:

1. Add the `aws_cloudwatch_metric_alarm` resource to the monitoring module
2. Include the `ClientId` dimension if the alarm is per-client (most alarms should be)
3. Reference the existing SNS topic for notifications
4. Add the alarm to [`docs/adr/alarms.md`](docs/adr/alarms.md) with threshold reasoning
5. Add the corresponding Logs Insights query to `monitoring/queries/logs-insights.md` if relevant
6. PR → review → merge → applied automatically

---

## Grafana dashboard updates

Dashboard JSON files live in `monitoring/grafana/dashboards/`. To update a dashboard:

1. Make changes in the Grafana UI
2. Export the dashboard as JSON (Dashboard settings → JSON Model → Copy to clipboard)
3. Save to the corresponding file in the repo
4. PR → review → merge

Never make dashboard changes that only exist in Grafana. If the Grafana instance is rebuilt, any changes not committed to the repo are lost.

---

## Secrets rotation

Secrets are stored in AWS Secrets Manager. WordPress reads them via `entrypoint.sh` at container startup — not at runtime. This means a secret rotation requires an ECS task restart to take effect.

**Rotation process:**

1. Update the secret value in Secrets Manager
2. Trigger an ECS task replacement: `aws ecs update-service --force-new-deployment`
3. ECS starts new tasks which read the updated secret via `entrypoint.sh`
4. Old tasks drain existing connections and stop

This is handled automatically for scheduled rotations via a Secrets Manager rotation Lambda. For manual rotations, follow this process to avoid a period where some tasks have the old secret and others have the new one.

---

## On-call and incident response

When an alarm fires:

1. **CRITICAL alarms** (SLO fast-burn, all tasks unhealthy, RDS unavailable) → PagerDuty phone escalation. Acknowledge within 5 minutes.
2. **HIGH alarms** (slow response, high CPU, connection count) → Slack `#platform-alerts`. Investigate within 2 hours during business hours.
3. **WARNING alarms** → Slack `#platform-warnings`. Address before next business day.

For each alarm, a runbook exists in `docs/runbooks/`. The Slack notification links directly to the relevant runbook. The first step in every runbook is the same: open the per-client Grafana dashboard for the affected client and look at the last 3 hours.

---

*Last updated: April 2026*
