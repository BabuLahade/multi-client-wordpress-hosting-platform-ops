# Architecture Decision Records

> This directory documents the significant technical decisions made during the design and build of this platform — what was decided, why, what alternatives were considered, and what trade-offs were accepted.

ADRs are written after the decision is made and implemented, not as proposals. They reflect reality, not intention.

---

## Index

| # | Decision | Status | Date |
|---|---|---|---|
| [001](001-valkey-over-redis.md) | Use Valkey instead of Redis | Accepted | 2025 |
| [002](002-fargate-over-ec2.md) | Use ECS Fargate instead of EC2 | Accepted | 2025 |
| [003](003-custom-docker-image.md) | Custom Docker image with WP-CLI and entrypoint.sh | Accepted | 2025 |
| [004](004-per-client-slo.md) | Per-client SLOs instead of platform-wide SLO | Accepted | 2025 |
| [005](005-session-storage.md) | File-based session storage (known gap) | Accepted with caveat | 2025 |
| [006](006-ecs-deployment-config.md) | ECS deployment minimumHealthyPercent = 100 | Accepted | 2025 |
| [007](007-rds-connection-limits.md) | Shared RDS instance with documented connection limit | Accepted | 2025 |

---

## ADR 001 — Valkey over Redis

**Status:** Accepted  
**Date:** 2025

### Context

The platform requires an object cache for WordPress to reduce database load and improve response times. The most common solution is Redis via AWS ElastiCache. In March 2024, Redis Labs changed the Redis licence from BSD to SSPL (Server Side Public Licence).

### Decision

Use Valkey on AWS ElastiCache instead of Redis.

### Reasoning

SSPL is not approved by the Open Source Initiative as an open-source licence. Its terms require any company that offers Redis as a service to release their entire infrastructure stack under SSPL — a condition that AWS, Google, and all major cloud providers cannot comply with.

Valkey is a fork of Redis created by the Linux Foundation in April 2024, starting from Redis 7.2.4. It maintains the original BSD licence. AWS, Google, Ericsson, and others are active contributors. It is functionally identical to Redis for the use cases in this project: WordPress object caching, session storage, transient caching.

The choice was made for long-term licence compliance, not because Redis had any functional deficiency.

### Alternatives considered

**Redis (SSPL)** — Rejected. Licence risk for any future commercial use of this platform.  
**Memcached** — Rejected. No persistence, no data types beyond strings, no pub/sub. Valkey is strictly more capable for the same cost.  
**DynamoDB for caching** — Rejected. Higher latency than in-memory cache, higher cost per operation, more complex WordPress plugin configuration.

### Trade-offs accepted

Valkey is newer than Redis. Documentation is less extensive. Some Redis-specific tooling may not support Valkey yet. These are acceptable trade-offs for licence compliance.

---

## ADR 002 — ECS Fargate over EC2

**Status:** Accepted  
**Date:** 2025

### Context

The platform needs to run three WordPress containers in a multi-tenant configuration. The choice is between managing EC2 instances that run the containers, or using Fargate which abstracts the underlying compute.

### Decision

Use ECS Fargate for all WordPress containers.

### Reasoning

Fargate eliminates the operational overhead of EC2 instance management: OS patching, security updates, capacity planning, instance right-sizing, and AMI maintenance. For a platform where the value is in the WordPress application isolation, not in EC2 configuration expertise, this overhead is wasted time.

Cost comparison for three containers running continuously:

- **EC2 t3.small (3 instances):** ~$45/month minimum, always-on even at zero traffic
- **Fargate (3 tasks, 512 CPU / 1024 MB):** ~$15/month, scales with actual usage

Fargate is cheaper at this scale because the tasks scale to zero when not in use.

### Alternatives considered

**EC2 with Auto Scaling Group** — Rejected. Higher management overhead, minimum cost higher than Fargate at this scale.  
**EKS Fargate** — Considered. Would add Kubernetes capabilities but significant operational overhead for three WordPress containers. EKS is used in Project 3 for the more complex platform use case.  
**Lambda** — Rejected. WordPress is a stateful PHP application with synchronous request handling. Lambda's execution model is a poor fit.

### Trade-offs accepted

Fargate has higher per-CPU-second cost than equivalent EC2. At sustained high traffic (10+ concurrent tasks per client), EC2 would be cheaper. The break-even point is approximately 5 Fargate tasks running continuously, at which point a reserved EC2 instance becomes more cost-effective.

---

## ADR 003 — Custom Docker Image with WP-CLI and entrypoint.sh

**Status:** Accepted  
**Date:** 2025

### Context

WordPress requires post-installation configuration: database setup, plugin installation, plugin activation, settings configuration. The official `wordpress:latest` Docker image requires a human to complete this configuration via the WordPress admin interface after each deployment.

### Decision

Build a custom Docker image that uses WP-CLI during the image build phase to install and activate required plugins. Use a custom `entrypoint.sh` script that reads environment variables at container start and generates `wp-config.php` automatically.

### Reasoning

Manual post-deployment configuration is a reliability risk. It requires a human to take action after every deployment. Human action is inconsistent, error-prone, and untrackable. A container that configures itself from environment variables is reproducible, auditable, and deployable without human intervention.

The custom image bakes the following into the build:
- Redis Object Cache plugin (for Valkey integration)
- WP Offload Media plugin (for S3 media storage)
- WP-CLI (for management operations)

`entrypoint.sh` reads the following from Terraform-injected environment variables:
- `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS` — from Secrets Manager
- `VALKEY_HOST` — ElastiCache endpoint
- `S3_BUCKET`, `S3_PREFIX` — for media offload
- `CLIENT_ID` — for cache key namespacing

### Alternatives considered

**Official `wordpress:latest` with manual setup** — Rejected. Manual steps are not reproducible at scale.  
**WordPress with a setup script run after deployment** — Rejected. Script execution requires a separate Lambda or ECS run task, adding complexity and failure modes.  
**WordPress with database import from S3** — Considered for initial data seeding. Not implemented — out of scope for the initial version.

### Trade-offs accepted

The custom Docker image must be rebuilt and tested when WordPress core updates or when plugin versions change. This is a maintenance overhead that does not exist with `wordpress:latest`. The trade-off is correct — reproducibility and zero-touch deployment are worth the rebuild overhead.

---

## ADR 004 — Per-Client SLOs Instead of Platform-Wide SLO

**Status:** Accepted  
**Date:** 2025

### Context

The platform needs a reliability measurement framework. The simplest approach is one SLO for the entire platform. The alternative is individual SLOs per client.

### Decision

Define SLOs per client, not per platform.

### Reasoning

A platform-wide SLO is calculated as aggregate across all requests from all clients. This creates a measurement problem: Client A can have a complete 4-hour outage while Clients B and C are healthy. The aggregate availability metric remains at 99.7% (because B and C are serving most of the traffic). Client A's experience — a full outage — is invisible in the aggregate number.

Per-client SLOs mean:
- Client A's error budget is consumed only by Client A's failures
- Client B's SLO report is unaffected by Client A's incidents
- The platform can have three green SLO dashboards and one red one — which accurately represents reality

This is the multi-tenancy principle applied to reliability measurement, not just to infrastructure.

### Alternatives considered

**Single platform SLO** — Rejected. Masks individual tenant reliability issues in aggregate metrics.  
**SLO per AWS service (one for RDS, one for ECS, etc.)** — Rejected. User-facing reliability is what matters, not service-layer availability. An SLO should measure what the tenant experiences, not what AWS reports.

### Trade-offs accepted

Three times the number of alarms, dashboards, and metrics to manage. This is the correct trade-off — the complexity is proportional to the problem being solved.

---

## ADR 005 — File-Based Session Storage (Known Gap)

**Status:** Accepted with caveat  
**Date:** 2025

### Context

WordPress stores user sessions on the filesystem by default. In a containerised, auto-scaling deployment, multiple containers may handle requests from the same user. If session files are stored per-container on the container's local filesystem, a user's session will be lost when their request is routed to a different container.

### Current state

WordPress session files are stored on EFS (not local container filesystem), which is mounted by all tasks for the same client. This prevents session loss from container switching because all tasks for Client A mount the same EFS access point.

### Why this is a caveat

EFS-based sessions introduce an I/O dependency for every authenticated page request. Under high load, this contributes to EFS I/O pressure and burst credit consumption (see Incident 4 in FAILURES.md).

The production-correct solution is to store sessions in DynamoDB or ElastiCache, which eliminates the EFS I/O dependency and scales independently of file system throughput.

### Planned migration

When EFS burst credit pressure becomes a consistent issue (tracked via the `BurstCreditBalance` CloudWatch alarm), migrate sessions to Valkey using the WP Redis Sessions plugin or DynamoDB using a custom WordPress session handler.

---

## ADR 006 — ECS Deployment minimumHealthyPercent = 100

**Status:** Accepted  
**Date:** 2025 (after Incident 2)

### Context

ECS rolling deployments have a `minimumHealthyPercent` configuration that controls whether old tasks can be stopped before new tasks are confirmed healthy.

### Decision

Set `minimumHealthyPercent = 100` and `maximumPercent = 200`.

### Reasoning

With `minimumHealthyPercent = 0` (ECS default), ECS stops all old tasks immediately when a deployment starts, before new tasks are healthy. If new tasks fail their health checks, the service has zero healthy tasks and is completely down.

With `minimumHealthyPercent = 100`, ECS starts new tasks first, waits for them to pass health checks, and only then stops old tasks. The service never drops below its current healthy capacity during a deployment. The trade-off is running at double capacity for 60–90 seconds per deployment — a small cost increase worth the zero-downtime guarantee.

This decision was made after Incident 2, where `minimumHealthyPercent = 0` combined with a failed health check caused an 8-minute complete outage.

---

## ADR 007 — Shared RDS Instance with Documented Connection Limits

**Status:** Accepted  
**Date:** 2025

### Context

Each client WordPress instance requires a MySQL database. The options are: one RDS instance with multiple databases (one per client), or one RDS instance per client.

### Decision

Use one shared RDS instance with separate databases per client. Database users are scoped to their own database only.

### Reasoning

A db.t3.micro RDS instance costs ~$15/month. Three separate instances would cost ~$45/month, an increase of $30/month for a three-client platform with no performance benefit at this scale.

Isolation is maintained at the database and user level — Client A's database user has `GRANT ALL PRIVILEGES ON wp_clienta.*` only, preventing cross-client data access.

### Known limitation

db.t3.micro has a `max_connections` limit of approximately 100. At three clients with three ECS tasks per client and eight PHP-FPM workers per task, peak connection usage can approach 72–90 connections. A simultaneous traffic spike across all three clients has triggered the connection limit in testing (see Incident 5 in FAILURES.md).

**Mitigation path:** RDS Proxy pools connections between ECS tasks and RDS, reducing the actual database connection count significantly regardless of PHP-FPM worker count. This is the planned upgrade path when the platform scales beyond three clients.

### Trade-offs accepted

Shared RDS means a db.t3.micro CPU spike from one client's slow queries can affect all three clients' query response times. At this scale, the cost saving is worth accepting this coupling. It is documented so it is not a surprise when it appears.

---

*Babu Lahade · Multi-Client WordPress Hosting Platform · 2025–2026*

ADR: Migrating S3 Offload Traffic from NAT Gateway to VPC Gateway Endpoint
Status: Accepted
Date: April 2026

1. Context and Problem Statement
To ensure our WordPress compute tier remains stateless, we utilize the WP Offload Media plugin to push all user uploads (images, videos, documents) directly to an AWS S3 bucket.

Initially, because our ECS Fargate containers reside in private subnets, their API calls to S3 were routed out to the public internet via our NAT Gateway. During scale-testing, we identified a critical cost-scaling bottleneck: AWS charges data processing fees per gigabyte for all traffic crossing the NAT Gateway. As client media uploads and downloads scale, NAT Gateway costs would increase linearly, creating an unacceptable financial overhead for a multi-tenant platform.

2. Decision
We decided to provision an Amazon S3 VPC Gateway Endpoint and update our private route tables to direct all S3-bound traffic through this endpoint rather than the NAT Gateway.

3. Consequences
Positive:

Cost Elimination: S3 Gateway Endpoints are provided by AWS at no additional charge. We completely eliminated NAT Gateway data processing fees for all media offloading.

Security Posture: Media traffic no longer traverses the public internet. It remains entirely within the AWS internal network backbone, satisfying enterprise data compliance requirements.

Latency Reduction: Direct routing to the S3 service removes the NAT Gateway as a network hop, marginally improving media upload speeds for the PHP workers.

Negative:

Routing Complexity: Requires explicit Terraform state management to ensure all current and future private subnet route tables are properly associated with the Gateway Endpoint prefix list.
