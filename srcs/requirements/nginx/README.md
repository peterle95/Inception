# NGINX Service

This container runs NGINX with TLS support.

## Configuration

- **Base Image**: Alpine 3.19
- **Port**: 443
- **TLS**: v1.2, v1.3
- **Certificate**: Self-signed (generated at startup)

## Dockerfile Details

Installs `nginx` and `openssl`. Copies the configuration and entrypoint script.
The entrypoint generates a self-signed certificate for `pmolzer.42.fr` if it doesn't exist.