## ARCHITECTURE 
      - system overview
      - network layout
      - services used
      - client onboarding flow
      - failure handling strategy

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