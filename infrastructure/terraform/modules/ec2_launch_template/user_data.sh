#!/bin/bash

DB_ENDPOINT="${db_endpoint}"

apt update -y
apt install docker.io docker-compose -y

systemctl start docker
systemctl enable docker

mkdir -p /app
cd /app

cat <<EOF > docker-compose.yml
version: "3.8"

services:

  wordpress:
    image: wordpress:latest
    restart: always

    environment:
      WORDPRESS_DB_HOST: ${DB_ENDPOINT}:3306
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: StrongPassword123!
      WORDPRESS_DB_NAME: wordpress

    volumes:
      - wordpress_data:/var/www/html

  nginx:
    image: nginx:latest
    restart: always

    ports:
      - "80:80"

    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf

    depends_on:
      - wordpress

volumes:
  wordpress_data:
EOF


cat <<EOF > nginx.conf
events {}

http {

  upstream wordpress {
      server wordpress:80;
  }

  server {
      listen 80;

      location / {
          proxy_pass http://wordpress;
          proxy_set_header Host \$host;
          proxy_set_header X-Real-IP \$remote_addr;
      }
  }

}
EOF


docker-compose up -d