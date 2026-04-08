
#### working zero touch script that waits for the web installer to be completed before activating plugins and enabling redis cache. it also force copies the plugins to the efs drive to ensure they are available when the container starts up for the first time.
#    zero-touch.sh
#!/bin/bash
set -e

# Start the official WordPress entrypoint in the background
/usr/local/bin/docker-entrypoint.sh "$@" &
WP_PID=$!

sleep 10

# THE EFS FIX: FORCE COPY THE PLUGINS!
echo "Syncing custom plugins to the EFS drive..."
cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
chown -R www-data:www-data /var/www/html/wp-content/plugins/

# THE RACE CONDITION FIX: Wait for web installation
echo "Waiting for WordPress tables to be installed..."
until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
  echo "WordPress not installed yet. Waiting 10 seconds..."
  sleep 10
done

echo "WordPress is fully installed! Running Zero-Touch configurations..."

echo "WordPress is fully installed! Running Zero-Touch configurations..."
# Force WordPress to dynamically accept wildcard subdomains
wp config set WP_HOME "https://\$_SERVER['HTTP_HOST']" --raw --allow-root
wp config set WP_SITEURL "https://\$_SERVER['HTTP_HOST']" --raw --allow-root

# Tell the S3 plugin to use the ECS IAM Role
wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root
# 1. Forcefully inject the Valkey endpoint into wp-config.php
if [ -n "$VALKEY_HOST" ]; then
    echo "Injecting Valkey host into config..."
    wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
    wp config set WP_REDIS_PORT 6379 --raw --allow-root
fi

# 2. Activate plugins and enable caching
wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
wp redis enable --path=/var/www/html --allow-root

echo "Zero-Touch complete! Serving application..."

wait $WP_PID