#!/bin/bash
set -xe

# Update system
apt update -y

# Install Docker
apt install -y docker.io -y

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Allow ec2-user to run docker
usermod -aG docker  ubuntu  && newgrp docker

# Install Docker Compose
# curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
# chmod +x /usr/local/bin/docker-compose
apt install docker-compose -y

# Create app directory
mkdir -p /home/ubuntu/wordpress-hosting
cd /home/ubuntu/wordpress-hosting

# Create docker-compose file
cat <<EOF > docker-compose.yml
version: '3.8'

services:

  wordpress:
    image: wordpress:latest
    container_name: wordpress-app
    restart: always
    environment:
      WORDPRESS_DB_HOST: ${db_endpoint}
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: Password@123
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - wordpress-network

  nginx:
    image: nginx:latest
    container_name: wordpress-nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - wordpress
    networks:
      - wordpress-network

volumes:
  wordpress_data:

networks:
  wordpress-network:
EOF


# Create nginx config
cat <<EOF > default.conf
server {
    listen 80;

    location / {
        proxy_pass http://wordpress:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Start containers
docker-compose up -d