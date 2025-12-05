#!/bin/sh
set -e

# Wait for MariaDB
while ! mariadb -h mariadb -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE --silent; do
    echo "Waiting for MariaDB..."
    sleep 2
done

echo "MariaDB is available."

# Download WordPress
if [ ! -f wp-config.php ]; then
    echo "WordPress configuration file not found. Starting installation..."

    # Check if directory is writable
    if [ ! -w . ]; then
        echo "Error: Current directory $(pwd) is not writable."
        exit 1
    fi

    echo "Downloading WordPress..."
    if wp core download --allow-root; then
        echo "WordPress downloaded successfully."
    else
        echo "Error: Failed to download WordPress."
        exit 1
    fi

    echo "Configuring WordPress..."
    if wp config create \
        --dbname=$MYSQL_DATABASE \
        --dbuser=$MYSQL_USER \
        --dbpass=$MYSQL_PASSWORD \
        --dbhost=mariadb \
        --allow-root; then
        echo "WordPress configured successfully."
    else
        echo "Error: Failed to configure WordPress."
        exit 1
    fi

    echo "Installing WordPress..."
    if wp core install \
        --url=$DOMAIN_NAME \
        --title="Inception" \
        --admin_user=$WP_ADMIN_USER \
        --admin_password=$WP_ADMIN_PASSWORD \
        --admin_email=$WP_ADMIN_EMAIL \
        --allow-root; then
        echo "WordPress installed successfully."
    else
        echo "Error: Failed to install WordPress."
        exit 1
    fi

    echo "Creating user..."
    if wp user create \
        $WP_USER \
        $WP_USER@example.com \
        --role=author \
        --user_pass=$WP_PASSWORD \
        --allow-root; then
        echo "User created successfully."
    else
        echo "Error: Failed to create user."
        exit 1
    fi
    
    # Ensure permissions are correct
    echo "Setting permissions..."
    chmod -R 755 /var/www/html
    chown -R www-data:www-data /var/www/html
else
    echo "WordPress is already installed."
fi

echo "Starting PHP-FPM..."
exec "$@"