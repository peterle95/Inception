#!/bin/sh

# Create SSL directory
mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
    echo "Generating SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=Inception/CN=peter.42.fr"
fi

echo "Starting NGINX..."
exec "$@"
