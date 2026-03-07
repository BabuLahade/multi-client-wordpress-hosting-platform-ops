## ARCHITECTURE 
 - system overview
      - network layout
      - services used
      - client onboarding flow
      - failure handling strategy
---
 ## System 
 ```
System :
   
   Route 53
      |
   Cloudfront CDN 
      |
     WAF
      |
  Application Load Balancer
      |
  Wordpress Containers (Docker/Kubernetes)
      |
  Redis Cache  
      |
   RDS MySQL 
      |
   s3 storage   
   ```
   ---

   # Architecture

## Overview

This platform hosts multiple WordPress sites using containerized infrastructure.

---

## Components

     - Nginx Gateway
- WordPress Containers
- MySQL Database
- Monitoring Stack

---

## Request Flow

1. User visits website
2. Nginx receives request
3. Nginx routes request to correct container
4. WordPress serves content

---

## Example Command

```bash
docker ps
```
```mermaid
flowchart TD

User[Client Browser]

CDN[Cloudflare CDN]
DNS[Route53]

LB[Load Balancer / Nginx Gateway]

Provision[Provisioning Service API]

WP1[WordPress Container - Client1]
WP2[WordPress Container - Client2]

DB[(MySQL / RDS Database)]

Storage[S3 Media Storage]

Monitoring[Prometheus]
Dash[Grafana]

User --> CDN
CDN --> DNS
DNS --> LB

LB --> WP1
LB --> WP2

WP1 --> DB
WP2 --> DB

WP1 --> Storage
WP2 --> Storage

Provision --> WP1
Provision --> WP2

Monitoring --> Dash
```