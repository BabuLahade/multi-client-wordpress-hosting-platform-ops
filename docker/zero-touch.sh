#!/bin/bash
set -e

# 1.  we will run the official WordPress entrypoint in the background to set up files
# We pass "$@" so it receives the default 'php-fpm' command

/usr/local/bin/docker-entrypoint.sh "$@" &
WP_PID=$!

#wait for the WordPress files to copy to  efs
sleep 10

# Wait for the database to be ready (Using WP-CLI)
echo "waiting for database onnection ....."
until wp db check --path=/var/www/html --allow-root > /dev/null 2>&1; do
    echo "waiting for database connection..."
    sleep 5
done 

echo "database connected successfully . now running zero touch script "


## activate plugins automatically
wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root

### enable redic cache 
wp redis enable --path=/var/www/html --allow-root

echo "zero touch script completed . now starting php-fpm"

# Wait for the WordPress entrypoint process to finish (if it hasn't already)
wait $WP_PID