#!/bin/sh

# Wait for MariaDB
while ! mariadb -h mariadb -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE --silent; do
    echo "Waiting for MariaDB..."
    sleep 2
done

# Download WordPress
if [ ! -f wp-config.php ]; then
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
fi

echo "Starting PHP-FPM..."
exec "$@"
