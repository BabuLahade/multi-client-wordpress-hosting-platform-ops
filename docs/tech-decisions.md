# Technology Decisions

This document explains why specific tools and services were selected for the platform.

---

## AWS EC2

Chosen for hosting the WordPress containers.

Reasons:

- flexible compute environment
- easy integration with other AWS services
- suitable for container workloads
- widely used in production environments

Alternative considered:

- Kubernetes
- AWS ECS

These were not chosen to keep the platform simpler while still demonstrating infrastructure automation.

---

## Docker

Used to containerize WordPress instances.

Benefits:

- isolation between client sites
- reproducible deployments
- easier scaling and management

Without containers, plugin conflicts or dependency issues could affect multiple sites.

---

## Nginx

Used as the reverse proxy gateway.

Responsibilities:

- route domains to correct WordPress containers
- handle SSL termination
- provide load balancing capability

Example routing:

client1.com → wordpress-container-1  
client2.com → wordpress-container-2

---

## Terraform

Used for Infrastructure as Code.

Reasons:

- declarative infrastructure management
- reproducible environments
- easy version control

Terraform allows infrastructure to be recreated quickly if a server fails.

---

## MySQL

Used as the WordPress database.

Reasons:

- WordPress native compatibility
- reliable relational database
- widely supported and documented

In production environments this would typically be hosted on AWS RDS.

---

## Amazon S3

Used for media storage.

Reasons:

- scalable object storage
- prevents local disk exhaustion
- allows CDN integration

Media files uploaded by WordPress can be stored externally instead of on the server.

---

## Prometheus + Grafana

Used for monitoring and observability.

Prometheus collects metrics such as:

- CPU usage
- memory consumption
- container health

Grafana provides dashboards for visualization.