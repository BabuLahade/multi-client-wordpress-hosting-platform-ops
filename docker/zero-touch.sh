# #!/bin/bash
# set -e

# # 1.  we will run the official WordPress entrypoint in the background to set up files
# # We pass "$@" so it receives the default 'php-fpm' command

# /usr/local/bin/docker-entrypoint.sh "$@" &
# WP_PID=$!

# #wait for the WordPress files to copy to  efs
# sleep 10

# # Wait for the database to be ready (Using WP-CLI)
# echo "waiting for database onnection ....."
# until wp db check --path=/var/www/html --allow-root > /dev/null 2>&1; do
#     echo "waiting for database connection..."
#     sleep 5
# done 

# echo "database connected successfully . now running zero touch script "


# ## activate plugins automatically
# # wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root

# # ### enable redic cache 
# # wp redis enable --path=/var/www/html --allow-root

# # echo "zero touch script completed . now starting php-fpm"

# # # Wait for the WordPress entrypoint process to finish (if it hasn't already)
# # wait $WP_PID

# #!/bin/bash
# set -e

# # 1. Start the official WordPress entrypoint in the background
# /usr/local/bin/docker-entrypoint.sh "$@" &
# WP_PID=$!

# # Wait for the entrypoint to finish its initial checks
# sleep 10

# # ==========================================
# # 2. THE EFS FIX: FORCE COPY THE PLUGINS!
# # ==========================================
# echo "Syncing custom plugins to the EFS drive..."
# cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
# cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true

# # Ensure WordPress has permission to read the new plugin files
# chown -R www-data:www-data /var/www/html/wp-content/plugins/

# # 3. Wait for the database
# echo "Waiting for database connection..."
# until wp db check --path=/var/www/html --allow-root > /dev/null 2>&1; do
#   echo "Database not ready, waiting 5 seconds..."
#   sleep 5
# done

# echo "Database connected! Running Zero-Touch configurations..."

# # 4. Activate plugins and enable caching
# wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
# wp redis enable --path=/var/www/html --allow-root

# echo "Zero-Touch complete! Serving application..."

# # 5. Keep the container running
# wait $WP_PID

#!/bin/bash
set -e

# 1. Start the official WordPress entrypoint in the background
/usr/local/bin/docker-entrypoint.sh "$@" &
WP_PID=$!

sleep 10

# 2. Force copy the plugins to the EFS drive
echo "Syncing custom plugins to the EFS drive..."
cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
chown -R www-data:www-data /var/www/html/wp-content/plugins/

# ==========================================
# 3. THE FIX: PREVENT THE RACE CONDITION
# ==========================================
echo "Waiting for WordPress tables to be installed..."
# This will loop infinitely until you finish the web installer in your browser!
until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
  echo "WordPress not installed yet. Waiting 10 seconds..."
  sleep 10
done

echo "WordPress is fully installed! Running Zero-Touch configurations..."

# 4. Activate plugins and enable caching
wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
wp redis enable --path=/var/www/html --allow-root

echo "Zero-Touch complete! Serving application..."

wait $WP_PID