# Disaster Recovery (DR) Runbook: Multi-Tenant WordPress Platform

## 1. Overview and Objectives
This document outlines the Disaster Recovery (DR) strategies and execution steps for the Multi-Tenant WordPress Hosting Platform. The architecture is designed to minimize data loss and downtime during both localized component failures and complete regional outages.

### Core Metrics
* **Recovery Point Objective (RPO):**
  * **Database (RDS):** 5 minutes (via Point-in-Time Recovery).
  * **Media/Files (EFS):** 24 hours (via AWS Backup daily snapshots).
* **Recovery Time Objective (RTO):**
  * **Compute/Network Failure:** < 3 minutes (Automated via Auto-Scaling & Terraform).
  * **Full Region Failure:** < 15 minutes (Manual execution via cross-region Terraform apply).

---

## 2. Architecture State Definition
To execute a successful recovery, it is critical to separate the infrastructure into stateless and stateful components. 

### Stateless Components (Do Not Backup)
These resources are codified in Terraform and can be rebuilt from scratch in minutes.
* **Network:** VPC, Subnets, Route Tables, NAT Gateways, Security Groups.
* **Compute:** Application Load Balancer (ALB), ECS Fargate Tasks.
* **Edge:** CloudFront CDN, Route53 DNS.
* **Cache:** Valkey (ElastiCache) Replication Group. *Architectural Decision: Cache is ephemeral. In a DR scenario, we deploy an empty cache and allow the application to rebuild it organically to save on cross-region backup costs.*

### Stateful Components (Critical Backups)
* **Database:** Amazon RDS (MySQL) - Automated backups enabled with 7-day retention.
* **Storage:** Amazon EFS (WordPress wp-content) - Managed via AWS Backup Vault.

---

## 3. Incident Scenarios and Execution Plans

### Scenario A: Accidental Database Deletion or Corruption
**Trigger:** A rogue SQL query (e.g., `DROP TABLE`) or corrupted WordPress update destroys client data.
**Execution:**
1. Identify the exact timestamp of the destructive event (e.g., `2026-04-21 14:30:00 UTC`).
2. Navigate to the AWS RDS Console.
3. Select the `wordpress-db` instance and choose **Restore to Point in Time**.
4. Set the custom restore time to 1 minute *before* the destructive event (e.g., `2026-04-21 14:29:00 UTC`).
5. Launch the restored database with a new identifier (e.g., `wordpress-db-restored`).
6. Once available, update the `RDS_HOST` variable in the AWS Secrets Manager / Terraform environment.
7. Run `terraform apply` or force an ECS new deployment to point the containers to the restored database.
8. Delete the corrupted database instance after verification.

### Scenario B: Accidental File Deletion (EFS)
**Trigger:** A client or compromised plugin deletes critical media uploads from the shared EFS volume.
**Execution:**
1. Navigate to AWS Backup -> **Protected Resources**.
2. Select the `wordpress-fs` EFS file system.
3. Choose the most recent daily backup recovery point.
4. Click **Restore**. Choose to restore to a *new* EFS file system.
5. Once the restore completes, update the `efs_file_system_id` in `terraform.tfvars`.
6. Run `terraform apply` to mount the restored EFS volume to the ECS Fargate tasks.

### Scenario C: Complete Region Failure (e.g., `eu-north-1` goes offline)
**Trigger:** AWS declares a major outage for the primary region.
**Execution:**
1. **Declare the Disaster:** Acknowledge the regional outage and initiate cross-region failover to `eu-central-1` (Frankfurt).
2. **Restore State (Data):**
   * Navigate to AWS Backup in the surviving region (`eu-central-1`).
   * Restore the latest EFS cross-region snapshot.
   * Restore the RDS database from the latest cross-region automated snapshot.
3. **Rebuild Stateless Infrastructure:**
   * Open the infrastructure repository locally.
   * Update `variables.tf` to set `aws_region = "eu-central-1"`.
   * Input the newly restored EFS ID and RDS endpoints into your `.tfvars` file.
   * Run `terraform init` and `terraform apply`. Terraform will recreate the VPC, ALB, ECS cluster, and Valkey cache in the new region.
4. **Reroute Traffic:**
   * Navigate to Route 53.
   * Update the Apex and Wildcard records to point to the new Application Load Balancer / CloudFront distribution.
5. **Verify:** Check Grafana dashboards to ensure `200 OK` health checks and expected baseline latency.

---

## 4. Post-Incident Review (PIR)
Following any execution of this runbook, the SRE team must compile a `FAILURE.md` incident report detailing:
1. Time to detection.
2. Actual RTO and RPO achieved vs. targets.
3. Steps taken to mitigate the root cause in the future.