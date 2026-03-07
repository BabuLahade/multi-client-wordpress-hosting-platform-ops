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

# System Architecture

## Overview

This platform provisions and hosts multiple WordPress websites for different clients using containerized infrastructure.

---

## High Level Architecture

```mermaid
flowchart TD

User[Client Browser]
DNS[Route53 DNS]
Gateway[Nginx Gateway]

WP1[WordPress Container - Client1]
WP2[WordPress Container - Client2]

DB1[(MySQL DB - Client1)]
DB2[(MySQL DB - Client2)]

User --> DNS
DNS --> Gateway

Gateway --> WP1
Gateway --> WP2

WP1 --> DB1
WP2 --> DB2
```

```mermaid
flowchart TD

User --> Cloudflare
Cloudflare --> Route53
Route53 --> EC2

EC2 --> Nginx
Nginx --> WordPress1
Nginx --> WordPress2

WordPress1 --> RDS1
WordPress2 --> RDS2

Prometheus --> Grafana
```

```mermaid
sequenceDiagram

User->>Nginx: HTTP Request
Nginx->>WordPress: Route to container
WordPress->>MySQL: Fetch data
MySQL-->>WordPress: Return data
WordPress-->>Nginx: HTML response
Nginx-->>User: Website page
```