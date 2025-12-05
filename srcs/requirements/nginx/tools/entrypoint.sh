#!/bin/bash

# Create SSL directory
mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
    echo "Generating SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=Inception/CN=pmolzer.42.fr"
fi

# Wait for WordPress to be available
echo "Waiting for WordPress..."
while ! getent hosts wordpress > /dev/null 2>&1; do
    sleep 1
done
echo "WordPress is available."

echo "Starting NGINX..."
exec "$@"