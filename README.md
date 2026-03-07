## project structure
``` bash 
wordpress-platform/
├── infrastructure          # Terraform / AWS resources
├── provisioning-service    # API that creates new WordPress sites
├── nginx-gateway           # Reverse proxy + domain routing
├── wordpress-template      # Base WordPress Docker image
├── monitoring              # Prometheus / Grafana configs
└── docs                    # Architecture and setup guides

```