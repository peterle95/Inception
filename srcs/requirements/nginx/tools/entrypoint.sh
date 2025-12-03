#!/bin/sh

# need shebang because alpine doesn't have /bin/bash
# alpine comes with ash by default

# Create SSL directory
mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
# if the certificate doesn't exist, generate it
# we use openssl to generate a self-signed certificate

# A self-signed certificate is a certificate that is not signed 
# by a certificate authority (CA)
# It is used for testing and development purposes
# A certificate authority is a trusted entity that issues digital certificates

# openssl is a tool to generate a self-signed certificate
# -x509: X.509 is a standard for public key infrastructure (PKI)
# -nodes: don't encrypt the private key
# -days: certificate validity period
# -newkey: generate a new private key
# rsa:2048: generate a 2048-bit RSA private key
# -keyout: output the private key
# -out: output the certificate
# -subj: subject of the certificate
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
    echo "Generating SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=Inception/CN=pmolzer.42.fr"
fi

# NGINX needs a certificate and a private key to start
# so we copy the certificate and the private key to the NGINX directory
# and then we start NGINX


echo "Starting NGINX..."
exec "$@"