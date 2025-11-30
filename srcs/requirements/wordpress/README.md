# WordPress Service

This container runs WordPress with PHP-FPM.

## Configuration

- **Base Image**: Alpine 3.19
- **Port**: 9000 (exposed to internal network)

## Dockerfile Details

Installs PHP 8.1 and extensions, and WP-CLI.
The entrypoint waits for MariaDB to be ready, then downloads and installs WordPress using WP-CLI.
It configures `wp-config.php` and creates the admin and normal users.