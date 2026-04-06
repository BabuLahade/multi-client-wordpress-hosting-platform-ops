# we pull fpm image like used in ecs 
FROM wordpress:fpm

# Install necessary packages and extensions wp cli
RUN apt-get update && apt-get -install -y unzip curl \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp 

### we will install redis plugin directly here 
RUN curl -o /usr/src/wordpress/wp-content/plugins/redis-cache.zip https://downloads.wordpress.org/plugin/redis-cache.latest-stable.zip \
    && unzip /usr/src/wordpress/wp-content/plugins/redis-cache.zip -d /usr/src/wordpress/wp-content/plugins/ \
    && rm /usr/src/wordpress/wp-content/plugins/redis-cache.zip

### we will download for s3 offload media plugin
RUN curl -o /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront.zip https://downloads.wordpress.org/plugin/amazon-s3-and-cloudfront.latest-stable.zip \
    && unzip /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront.zip -d /usr/src/wordpress/wp-content/plugins/ \
    && rm /usr/src/wordpress/wp-content/plugins/amazon-s3-and-cloudfront.zip

#### we will add custom startup script to handle some of the configuration at runtime
COPY zero-touch.sh /usr/local/bin/zero-touch.sh
RUN chmod +x /usr/local/bin/zero-touch.sh

#####change default entrypointof script to our custom script
ENTRYPOINT ["/usr/local/bin/zero-touch.sh"]
CMD ["php-fpm"]