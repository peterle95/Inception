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
# we need to use getent to wait for the container to be available
# getent is a command that returns the entry for a name in the database
# while ! getent hosts wordpress > /dev/null 2>&1; do basically means while the container is not available, wait
while ! getent hosts wordpress > /dev/null 2>&1; do
    sleep 1
done
echo "WordPress is available."

echo "Starting NGINX..."
exec "$@" # replaces the shell process, ensuring that the container runs as PID 1