FROM alpine:3.19

RUN apk update && apk add --no-cache \
    php81 \
    php81-fpm \
    php81-mysqli \
    php81-phar \
    php81-iconv \
    php81-mbstring \
    php81-openssl \
    curl \
    mariadb-client

RUN ln -s /usr/bin/php81 /usr/bin/php

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Copy PHP-FPM and PHP configuration files
COPY conf/www.conf /etc/php81/php-fpm.d/www.conf
COPY conf/custom.ini /etc/php81/conf.d/custom.ini

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm81", "-F"]