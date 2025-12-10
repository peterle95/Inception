FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    php8.2 \
    php8.2-fpm \
    php8.2-mysqli \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-curl \
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Copy PHP-FPM configuration
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
# the custom.ini file is used to set the PHP-FPM configuration
COPY conf/custom.ini /etc/php/8.2/fpm/conf.d/99-custom.ini

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create necessary directories with correct permissions
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html && \
    mkdir -p /run/php && \
    chown -R www-data:www-data /run/php

# WORKDIR is the directory where the command will be executed
WORKDIR /var/www/html

# EXPOSE is used to inform Docker that the container will listen on the specified port at runtime
EXPOSE 9000

# ENTRYPOINT is used to run a command as the container starts
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# CMD is used to run a command as the container starts
# php-fpm8.2 is the command to run
# PID 1 is the main process of the container, and it is achieved by using the -F flag
CMD ["php-fpm8.2", "-F"]