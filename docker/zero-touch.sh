#!/bin/bash
set -e

# 1. FIX THE ALB IMMEDIATELY 
echo "Copying SRE health check..."
cp /tmp/health.php /var/www/html/health.php || true

# ==============================================================================
# 2. THE BACKGROUND OBSERVER (Waits patiently without blocking the container)
# ==============================================================================
(
    echo "Waiting 15 seconds for WordPress to generate core files..."
    sleep 15

    # SSL Reverse Proxy Fix
    if [ -f /var/www/html/wp-config.php ] && ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
        echo "Injecting flawless SSL Proxy fix via AWK..."
        awk '/<\?php/ { print; print "$_SERVER[\"HTTPS\"] = \"on\";"; print "$_SERVER[\"SERVER_PORT\"] = 443;"; print "$_SERVER[\"HTTP_X_FORWARDED_PROTO\"] = \"https\";"; print "define(\"FORCE_SSL_ADMIN\", true);"; next }1' /var/www/html/wp-config.php > /var/www/html/wp-config.tmp
        mv /var/www/html/wp-config.tmp /var/www/html/wp-config.php
        chown www-data:www-data /var/www/html/wp-config.php
    fi

    # Wait for the user to finish the web installation
    echo "Waiting for WordPress tables to be installed..."
    until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
      sleep 10
    done

    echo "WordPress is fully installed! Running Zero-Touch configurations..."

    # Sync Plugins
    echo "Syncing custom plugins to the EFS drive..."
    cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
    cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
    chown -R www-data:www-data /var/www/html/wp-content/plugins/

    wp config set WP_HOME "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
    wp config set WP_SITEURL "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
    wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root

    # Valkey / Redis Setup
    if [ -n "$VALKEY_HOST" ]; then
        wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
        wp config set WP_REDIS_PORT 6379 --raw --allow-root
        
        if [ -n "$CLIENT_ID" ]; then
            echo "Applying Redis cache isolation for client: $CLIENT_ID"
            wp config set WP_CACHE_KEY_SALT "${CLIENT_ID}_" --allow-root
            wp config set WP_REDIS_PREFIX "${CLIENT_ID}_" --allow-root
        fi
    fi

    wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
    wp redis enable --path=/var/www/html --allow-root
    wp redis flush --path=/var/www/html --allow-root || true

    echo "Zero-Touch background configuration complete!"
) &  # <--- THE AMPERSAND HERE SENDS ALL OF THIS TO THE BACKGROUND

# ==============================================================================
# 3. FOREGROUND THE MAIN PROCESS (This keeps the container alive and opens Port 9000)
# ==============================================================================
echo "Starting official WordPress entrypoint..."
exec /usr/local/bin/docker-entrypoint.sh "$@"


### updating new script



# #!/bin/bash
# set -e

# echo "Copying SRE health check..."
# cp /tmp/health.php /var/www/html/health.php || true

# # Start the official WordPress entrypoint in the background
# /usr/local/bin/docker-entrypoint.sh "$@" &
# WP_PID=$!

# # 1. BEAT THE RACE CONDITION
# # The entrypoint takes about 5-10 seconds to create the file. We wait 15.
# echo "Waiting 15 seconds for WordPress to generate core files..."
# sleep 15

# # 2. THE BULLETPROOF AWK SSL INJECTION
# # awk finds <?php and perfectly inserts our secure overrides directly below it on line 2.
# if [ -f /var/www/html/wp-config.php ] && ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
#     echo "Injecting flawless SSL Proxy fix via AWK..."
#     awk '/<\?php/ {
#         print;
#         print "$_SERVER[\"HTTPS\"] = \"on\";";
#         print "$_SERVER[\"SERVER_PORT\"] = 443;";
#         print "$_SERVER[\"HTTP_X_FORWARDED_PROTO\"] = \"https\";";
#         print "define(\"FORCE_SSL_ADMIN\", true);";
#         next
#     }1' /var/www/html/wp-config.php > /var/www/html/wp-config.tmp
    
#     mv /var/www/html/wp-config.tmp /var/www/html/wp-config.php
#     chown www-data:www-data /var/www/html/wp-config.php
# fi

# # 3. Wait for the user to finish the web installation
# echo "Waiting for WordPress tables to be installed..."
# until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
#   echo "WordPress not installed yet. Waiting 10 seconds..."
#   sleep 10
# done

# echo "WordPress is fully installed! Running Zero-Touch configurations..."

# # 4. Sync Plugins and configure database
# echo "Syncing custom plugins to the EFS drive..."
# cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
# cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
# chown -R www-data:www-data /var/www/html/wp-content/plugins/

# wp config set WP_HOME "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# wp config set WP_SITEURL "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root

# if [ -n "$VALKEY_HOST" ]; then
#     wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
#     wp config set WP_REDIS_PORT 6379 --raw --allow-root

#     if [ -n "$CLIENT_ID" ]; then
#         echo "Applying Redis cache isolation for client: $CLIENT_ID"
#         wp config set WP_CACHE_KEY_SALT "${CLIENT_ID}_" --allow-root
#         wp config set WP_REDIS_PREFIX "${CLIENT_ID}_" --allow-root
#     else
#         echo "WARNING: CLIENT_ID is not set! Cache is NOT isolated."
#     fi
# fi

# wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
# wp redis enable --path=/var/www/html --allow-root

# echo "Zero-Touch complete! Serving application..."
# wait $WP_PID


# #!/bin/bash
# set -e

# # Start the official WordPress entrypoint in the background
# /usr/local/bin/docker-entrypoint.sh "$@" &
# WP_PID=$!

# # --- 1. THE NUCLEAR EFS RESET ---
# # Delete the corrupted config so WordPress is forced to rebuild it cleanly
# if [ -f /var/www/html/wp-config.php ]; then
#     echo "CRITICAL: Deleting corrupted wp-config.php from EFS..."
#     rm -f /var/www/html/wp-config.php
# fi

# # 2. WAIT FOR THE NEW FILE TO BE CREATED
# echo "Waiting for the fresh wp-config.php to be generated..."
# while [ ! -f /var/www/html/wp-config.php ]; do
#   sleep 2
# done

# # 3. THE FOOLPROOF MIXED CONTENT SSL FIX
# echo "Injecting SSL Proxy fix into the fresh config..."
# if ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
#     # Insert the PHP server variables directly before the 'stop editing' comment
#     sed -i "/That's all, stop editing/i \$_SERVER['HTTPS'] = 'on';\n\$_SERVER['HTTP_X_FORWARDED_PROTO'] = 'https';\n\$_SERVER['SERVER_PORT'] = 443;" /var/www/html/wp-config.php
# fi

# # 4. THE RACE CONDITION FIX
# echo "Waiting for WordPress tables to be installed..."
# until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
#   echo "WordPress not installed yet. Waiting 10 seconds..."
#   sleep 10
# done

# echo "WordPress is fully installed! Running Zero-Touch configurations..."

# echo "Syncing custom plugins to the EFS drive..."
# cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
# cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
# chown -R www-data:www-data /var/www/html/wp-content/plugins/

# wp config set WP_HOME "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# wp config set WP_SITEURL "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root

# if [ -n "$VALKEY_HOST" ]; then
#     wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
#     wp config set WP_REDIS_PORT 6379 --raw --allow-root
# fi

# wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
# wp redis enable --path=/var/www/html --allow-root

# echo "Zero-Touch complete! Serving application..."
# wait $WP_PID
# #  above updated for delete corrupted efs 

# # #!/bin/bash
# # set -e

# # # Start the official WordPress entrypoint in the background
# # /usr/local/bin/docker-entrypoint.sh "$@" &
# # WP_PID=$!

# # # 1. WAIT FOR THE FILE TO BE CREATED
# # echo "Waiting for wp-config.php to be generated..."
# # while [ ! -f /var/www/html/wp-config.php ]; do
# #   sleep 2
# # done

# # # 2. THE EFS SELF-HEALING FIX
# # echo "Healing corrupted EFS wp-config.php..."
# # sed -i '/WP_HOME/d' /var/www/html/wp-config.php
# # sed -i '/WP_SITEURL/d' /var/www/html/wp-config.php

# # # 3. THE FOOLPROOF MIXED CONTENT SSL FIX
# # echo "Injecting SSL Proxy fix..."
# # if ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
# #     # Insert the PHP server variables directly before the 'stop editing' comment
# #     sed -i "/That's all, stop editing/i \$_SERVER['HTTPS'] = 'on';\n\$_SERVER['HTTP_X_FORWARDED_PROTO'] = 'https';\n\$_SERVER['SERVER_PORT'] = 443;" /var/www/html/wp-config.php
# # fi

# # # 4. THE RACE CONDITION FIX
# # echo "Waiting for WordPress tables to be installed..."
# # until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
# #   echo "WordPress not installed yet. Waiting 10 seconds..."
# #   sleep 10
# # done

# # echo "WordPress is fully installed! Running Zero-Touch configurations..."

# # echo "Syncing custom plugins to the EFS drive..."
# # cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
# # cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
# # chown -R www-data:www-data /var/www/html/wp-content/plugins/

# # wp config set WP_HOME "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# # wp config set WP_SITEURL "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# # wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root

# # if [ -n "$VALKEY_HOST" ]; then
# #     wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
# #     wp config set WP_REDIS_PORT 6379 --raw --allow-root
# # fi

# # wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
# # wp redis enable --path=/var/www/html --allow-root

# # echo "Zero-Touch complete! Serving application..."
# # wait $WP_PID


# # #  updated script 

# # # #!/bin/bash
# # # set -e

# # # # Start the official WordPress entrypoint in the background
# # # /usr/local/bin/docker-entrypoint.sh "$@" &
# # # WP_PID=$!

# # # sleep 5 # Give the entrypoint a moment to generate files

# # # # --- THE EFS SELF-HEALING FIX ---
# # # # Scrub any corrupted PHP lines from the persistent EFS drive so WP-CLI can boot
# # # if [ -f /var/www/html/wp-config.php ]; then
# # #     echo "Healing corrupted EFS wp-config.php..."
# # #     sed -i '/WP_HOME/d' /var/www/html/wp-config.php
# # #     sed -i '/WP_SITEURL/d' /var/www/html/wp-config.php
# # # fi

# # # # --- MOVED UP: THE MIXED CONTENT FIX ---
# # # # Tell WordPress it is behind a secure Load Balancer BEFORE the user tries to install it!
# # # if [ -f /var/www/html/wp-config.php ]; then
# # #     if ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
# # #         echo "Injecting SSL Proxy fix..."
# # #         sed -i "s/<?php/<?php\n\$_SERVER['HTTPS']='on';\n\$_SERVER['HTTP_X_FORWARDED_PROTO']='https';/g" /var/www/html/wp-config.php
# # #     fi
# # # fi

# # # # --- THE RACE CONDITION FIX ---
# # # # Wait for web installation FIRST
# # # echo "Waiting for WordPress tables to be installed..."
# # # until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
# # #   echo "WordPress not installed yet. Waiting 10 seconds..."
# # #   sleep 10
# # # done

# # # echo "WordPress is fully installed! Running Zero-Touch configurations..."

# # # # THE EFS FIX: NOW copy the plugins
# # # echo "Syncing custom plugins to the EFS drive..."
# # # cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
# # # cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
# # # chown -R www-data:www-data /var/www/html/wp-content/plugins/

# # # # THE SUBDOMAIN FIX: Force WordPress to accept wildcard subdomains
# # # wp config set WP_HOME "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# # # wp config set WP_SITEURL "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root

# # # # Tell the S3 plugin to use the ECS IAM Role
# # # wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root

# # # # Forcefully inject the Valkey endpoint into wp-config.php
# # # if [ -n "$VALKEY_HOST" ]; then
# # #     echo "Injecting Valkey host into config..."
# # #     wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
# # #     wp config set WP_REDIS_PORT 6379 --raw --allow-root
# # # fi

# # # # Activate plugins and enable caching
# # # wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
# # # wp redis enable --path=/var/www/html --allow-root

# # # echo "Zero-Touch complete! Serving application..."

# # # wait $WP_PID

# # # #### above is newest with modifications 
# # # # #!/bin/bash
# # # # set -e

# # # # # Start the official WordPress entrypoint in the background
# # # # /usr/local/bin/docker-entrypoint.sh "$@" &
# # # # WP_PID=$!

# # # # sleep 5 # Give the entrypoint a moment to generate files

# # # # # --- THE EFS SELF-HEALING FIX ---
# # # # # Scrub any corrupted PHP lines from the persistent EFS drive so WP-CLI can boot
# # # # if [ -f /var/www/html/wp-config.php ]; then
# # # #     echo "Healing corrupted EFS wp-config.php..."
# # # #     sed -i '/WP_HOME/d' /var/www/html/wp-config.php
# # # #     sed -i '/WP_SITEURL/d' /var/www/html/wp-config.php
# # # # fi

# # # # # THE RACE CONDITION FIX: Wait for web installation FIRST
# # # # echo "Waiting for WordPress tables to be installed..."
# # # # until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
# # # #   echo "WordPress not installed yet. Waiting 10 seconds..."
# # # #   sleep 10
# # # # done

# # # # echo "WordPress is fully installed! Running Zero-Touch configurations..."

# # # # # THE MIXED CONTENT FIX: Tell WordPress it is behind a secure Load Balancer
# # # # # (Using grep ensures we don't add this 100 times if the container restarts)
# # # # if ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
# # # #     sed -i "s/<?php/<?php\n\$_SERVER['HTTPS']='on';\n\$_SERVER['HTTP_X_FORWARDED_PROTO']='https';/g" /var/www/html/wp-config.php
# # # # fi

# # # # # THE EFS FIX: NOW copy the plugins
# # # # echo "Syncing custom plugins to the EFS drive..."
# # # # cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
# # # # cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
# # # # chown -R www-data:www-data /var/www/html/wp-content/plugins/

# # # # # THE SUBDOMAIN FIX: Force WordPress to accept wildcard subdomains (Corrected Syntax!)
# # # # wp config set WP_HOME "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# # # # wp config set WP_SITEURL "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root

# # # # # Tell the S3 plugin to use the ECS IAM Role
# # # # wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root

# # # # # Forcefully inject the Valkey endpoint into wp-config.php
# # # # if [ -n "$VALKEY_HOST" ]; then
# # # #     echo "Injecting Valkey host into config..."
# # # #     wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
# # # #     wp config set WP_REDIS_PORT 6379 --raw --allow-root
# # # # fi

# # # # # Activate plugins and enable caching
# # # # wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
# # # # wp redis enable --path=/var/www/html --allow-root

# # # # echo "Zero-Touch complete! Serving application..."

# # # # wait $WP_PID


# # # # #### above is latest and woring 



# # # # # #### working zero touch script that waits for the web installer to be completed before activating plugins and enabling redis cache. it also force copies the plugins to the efs drive to ensure they are available when the container starts up for the first time.
# # # # # #    zero-touch.sh
# # # # # #!/bin/bash
# # # # # set -e

# # # # # # Start the official WordPress entrypoint in the background
# # # # # /usr/local/bin/docker-entrypoint.sh "$@" &
# # # # # WP_PID=$!

# # # # # sleep 10

# # # # # # THE EFS FIX: FORCE COPY THE PLUGINS!
# # # # # echo "Syncing custom plugins to the EFS drive..."
# # # # # cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
# # # # # cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
# # # # # chown -R www-data:www-data /var/www/html/wp-content/plugins/

# # # # # # THE RACE CONDITION FIX: Wait for web installation
# # # # # echo "Waiting for WordPress tables to be installed..."
# # # # # until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
# # # # #   echo "WordPress not installed yet. Waiting 10 seconds..."
# # # # #   sleep 10
# # # # # done

# # # # # echo "WordPress is fully installed! Running Zero-Touch configurations..."

# # # # # echo "WordPress is fully installed! Running Zero-Touch configurations..."
# # # # # # Force WordPress to dynamically accept wildcard subdomains
# # # # # wp config set WP_HOME "https://\$_SERVER['HTTP_HOST']" --raw --allow-root
# # # # # wp config set WP_SITEURL "https://\$_SERVER['HTTP_HOST']" --raw --allow-root

# # # # # # Tell the S3 plugin to use the ECS IAM Role
# # # # # wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root
# # # # # # 1. Forcefully inject the Valkey endpoint into wp-config.php
# # # # # if [ -n "$VALKEY_HOST" ]; then
# # # # #     echo "Injecting Valkey host into config..."
# # # # #     wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
# # # # #     wp config set WP_REDIS_PORT 6379 --raw --allow-root
# # # # # fi

# # # # # # 2. Activate plugins and enable caching
# # # # # wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
# # # # # wp redis enable --path=/var/www/html --allow-root

# # # # # echo "Zero-Touch complete! Serving application..."

# # # # # wait $WP_PID

# # # # # ###### updated 
# # # # # #!/bin/bash
# # # # # set -e

# # # # # # Start the official WordPress entrypoint in the background
# # # # # /usr/local/bin/docker-entrypoint.sh "$@" &
# # # # # WP_PID=$!

# # # # # sleep 5 # Give the entrypoint a moment to generate files

# # # # # # --- THE EFS SELF-HEALING FIX ---
# # # # # # Scrub any corrupted PHP lines from the persistent EFS drive so WP-CLI can boot
# # # # # if [ -f /var/www/html/wp-config.php ]; then
# # # # #     echo "Healing corrupted EFS wp-config.php..."
# # # # #     sed -i '/WP_HOME/d' /var/www/html/wp-config.php
# # # # #     sed -i '/WP_SITEURL/d' /var/www/html/wp-config.php
# # # # # fi

# # # # # # THE RACE CONDITION FIX: Wait for web installation FIRST
# # # # # echo "Waiting for WordPress tables to be installed..."
# # # # # until wp core is-installed --path=/var/www/html --allow-root > /dev/null 2>&1; do
# # # # #   echo "WordPress not installed yet. Waiting 10 seconds..."
# # # # #   sleep 10
# # # # # done

# # # # # echo "WordPress is fully installed! Running Zero-Touch configurations..."

# # # # # # THE MIXED CONTENT FIX: Tell WordPress it is behind a secure Load Balancer
# # # # # # (Using grep ensures we don't add this 100 times if the container restarts)
# # # # # if ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
# # # # #     sed -i "s/<?php/<?php\n\$_SERVER['HTTPS']='on';\n\$_SERVER['HTTP_X_FORWARDED_PROTO']='https';/g" /var/www/html/wp-config.php
# # # # # fi

# # # # # # THE EFS FIX: NOW copy the plugins
# # # # # echo "Syncing custom plugins to the EFS drive..."
# # # # # cp -rn /usr/src/wordpress/wp-content/plugins/redis-cache /var/www/html/wp-content/plugins/ || true
# # # # # cp -rn /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront /var/www/html/wp-content/plugins/ || true
# # # # # chown -R www-data:www-data /var/www/html/wp-content/plugins/

# # # # # # THE SUBDOMAIN FIX: Force WordPress to accept wildcard subdomains (Corrected Syntax!)
# # # # # wp config set WP_HOME "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root
# # # # # wp config set WP_SITEURL "'https://' . \$_SERVER['HTTP_HOST']" --raw --allow-root

# # # # # # Tell the S3 plugin to use the ECS IAM Role
# # # # # wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --raw --allow-root

# # # # # # Forcefully inject the Valkey endpoint into wp-config.php
# # # # # if [ -n "$VALKEY_HOST" ]; then
# # # # #     echo "Injecting Valkey host into config..."
# # # # #     wp config set WP_REDIS_HOST "$VALKEY_HOST" --allow-root
# # # # #     wp config set WP_REDIS_PORT 6379 --raw --allow-root
# # # # # fi

# # # # # # Activate plugins and enable caching
# # # # # wp plugin activate redis-cache amazon-s3-and-cloudfront --path=/var/www/html --allow-root
# # # # # wp redis enable --path=/var/www/html --allow-root

# # # # # echo "Zero-Touch complete! Serving application..."

# # # # # wait $WP_PID