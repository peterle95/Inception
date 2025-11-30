# MariaDB Service

This container runs MariaDB database.

## Configuration

- **Base Image**: Alpine 3.19
- **Port**: 3306 (exposed to internal network)
- **Bind Address**: 0.0.0.0

## Dockerfile Details

Installs `mariadb` and `mariadb-client`.
The entrypoint initializes the database, creates the root user and the WordPress user/database based on environment variables.