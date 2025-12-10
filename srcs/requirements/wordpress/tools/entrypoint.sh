#!/bin/bash

# set -e is used to exit the script if a command fails
set -e

# Read confidential information from Docker secrets
if [ -f /run/secrets/db_password ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
    export MYSQL_PASSWORD
fi

if [ -f /run/secrets/credentials ]; then
    WP_ADMIN_USER=$(grep '^username=' /run/secrets/credentials | cut -d'=' -f2)
    WP_ADMIN_PASSWORD=$(grep '^password=' /run/secrets/credentials | cut -d'=' -f2)
    export WP_ADMIN_USER WP_ADMIN_PASSWORD
fi

# Ensure correct permissions
chown -R www-data:www-data /var/www/html

# Wait for MariaDB
while ! mariadb -h mariadb -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE --silent 2>/dev/null; do
    echo "Waiting for MariaDB..."
    sleep 2
done

echo "MariaDB is available."

# Download WordPress
if [ ! -f wp-config.php ]; then
    echo "WordPress configuration file not found. Starting installation..."

    echo "Downloading WordPress..."
    wp core download --allow-root

    echo "Configuring WordPress..."
    wp config create \
        --dbname=$MYSQL_DATABASE \
        --dbuser=$MYSQL_USER \
        --dbpass=$MYSQL_PASSWORD \
        --dbhost=mariadb \
        --allow-root

    echo "Installing WordPress..."
    wp core install \
        --url=$DOMAIN_NAME \
        --title="Inception" \
        --admin_user=$WP_ADMIN_USER \
        --admin_password=$WP_ADMIN_PASSWORD \
        --admin_email=$WP_ADMIN_EMAIL \
        --allow-root

    echo "Creating user..."
    wp user create \
        $WP_USER \
        $WP_USER@example.com \
        --role=author \
        --user_pass=$WP_PASSWORD \
        --allow-root

    # Fix permissions after installation
    chown -R www-data:www-data /var/www/html
else
    echo "WordPress is already installed."
fi

echo "Starting PHP-FPM..."
exec "$@"