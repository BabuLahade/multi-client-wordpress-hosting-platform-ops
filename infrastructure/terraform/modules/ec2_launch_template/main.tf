# resource "aws_launch_template" "app_launch_template" {
#     name_prefix = "${var.project_name}-app-launch-template-"
#     image_id = var.ami_id
#     instance_type = var.instance_type
#     iam_instance_profile {
#       name = var.iam_instance_profile_name
#     }
    
#     key_name = var.key_name
#     network_interfaces {
#         # associate_public_ip_address = true
#         security_groups = [var.app_security_group_id]
#     }
    
#     user_data = base64encode(templatefile("${path.module}/userdata.sh", {
#      db_endpoint = module.rds.db_instance_endpoint
#     }))

#     user_data = #!/bin/bash
#                 DB_ENDPOINT=${db_endpoint}
#                 apt update -y
#                 apt install docker.io -y
#                 apt install docker-compose -y
#                 systemctl start docker
#                 systemctl enable docker

#                 usermod -aG docker ubuntu && newgrp docker

#                 mkdir app/
#                 cd app/
                
#                 cat <<EOF > docker-compose.yml
#                 version: "3.8"

#                 services:

#                 wordpress:
#                     image: wordpress:latest
#                     container_name: wordpress-app
#                     restart: always

#                     environment:
#                     WORDPRESS_DB_HOST: ${DB_ENDPOINT}:3306
#                     WORDPRESS_DB_USER: admin
#                     WORDPRESS_DB_PASSWORD: StrongPassword123!
#                     WORDPRESS_DB_NAME: wordpress

#                     volumes:
#                     - wordpress_data:/var/www/html

#                 nginx:
#                     image: nginx:latest
#                     container_name: wordpress-nginx
#                     restart: always

#                     ports:
#                     - "80:80"

#                     volumes:
#                     - ./nginx.conf:/etc/nginx/nginx.conf

#                     depends_on:
#                     - wordpress

#                 volumes:
#                 wordpress_data:

#                 cat <<EOF >nginx.conf
                



#                 upstream wordpress {
#                     server wordpress:80;
#                 }

#                 server {
#                     listen 80;

#                     location / {
#                         proxy_pass http://wordpress;
#                         proxy_set_header Host $host;
#                         proxy_set_header X-Real-IP $remote_addr;
#                     }

#                 }
# }

resource "aws_launch_template" "app_launch_template_1" {

  name_prefix   = "${var.project_name}-app-launch-template-1-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  network_interfaces {
    security_groups = [var.app_security_group_id]
  }

  user_data = base64encode(
    templatefile("${path.module}/user_data.sh", {
      db_endpoint = var.db_instance_address
      db_name= "wp_client_1"
      name = "client1.local"
    })
  ) 
}


resource "aws_launch_template" "app_launch_template_2" {

  name_prefix   = "${var.project_name}-app-launch-template-2-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  network_interfaces {
    security_groups = [var.app_security_group_id]
  }

  user_data = base64encode(
    templatefile("${path.module}/user_data.sh", {
      db_endpoint = var.db_instance_address
      db_name = "wp_client_2"
      name = "client2.local"
    })
  ) 
}