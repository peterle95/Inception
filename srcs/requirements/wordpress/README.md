# WordPress Container Documentation

## 1. Container Overview

### Purpose and Role
The WordPress container hosts the application logic for the Inception project. It runs the PHP-FPM (FastCGI Process Manager) server to process PHP requests forwarded by Nginx and communicates with the MariaDB database to retrieve and store content.

### Key Responsibilities
- **Application Logic**: Executes WordPress PHP code.
- **Content Management**: Handles content creation, modification, and retrieval.
- **Database Interaction**: Connects to MariaDB to persist data.
- **CLI Management**: Provides WP-CLI for command-line administration.

### Relationship to Other Services
- **Nginx**: Receives requests from Nginx on port 9000.
- **MariaDB**: Connects to the mariadb container on port 3306.
- **Volumes**: Mounts the shared wordpress volume to store core files and uploads.

## 2. Technical Specifications

### Software Packages
- **OS Base**: Debian Bookworm (Stable)
- **Runtime**: PHP 8.2 (FPM)
- **Extensions**: php8.2-mysqli, php8.2-mbstring, php8.2-xml, php8.2-curl
- **Tools**: 
  - curl: For downloading resources.
  - wp-cli: Command-line interface for WordPress management.
  - mariadb-client: For database connectivity checks.

### Dependencies
- **Database**: Requires a running MariaDB instance.
- **Secrets**: Requires db_password and credentials secrets.
- **Volume**: Requires read/write access to /var/www/html.

## 3. Configuration

### Configuration Files
- **PHP-FPM Pool**: /etc/php/8.2/fpm/pool.d/www.conf
  - Configures the pool to listen on port 9000.
  - Sets user/group to www-data.
  - Configures dynamic process management.
- **PHP Custom Settings**: /etc/php/8.2/fpm/conf.d/99-custom.ini
  - memory_limit: 512M
  - upload_max_filesize: 64M
  - post_max_size: 64M

### Environment Variables & Secrets
- **Secrets**:
  - db_password: Database user password.
  - credentials: Contains admin username and password for WordPress setup.
- **Environment Variables**:
  - MYSQL_DATABASE, MYSQL_USER: Database connection details.
  - DOMAIN_NAME: The site URL (e.g., pmolzer.42.fr).
  - WP_USER, WP_PASSWORD, WP_ADMIN_EMAIL: Details for initial user creation.

### Security Considerations
- **Least Privilege**: Runs as www-data user (configured in pool), not root.
- **Secrets**: Credentials are read from protected files, not environment variables where possible.
- **Permissions**: Entrypoint script enforces correct ownership (www-data:www-data) on web directories.

## 4. Dockerfile Analysis

`dockerfile
FROM debian:bookworm

# Install PHP and dependencies
RUN apt-get update && apt-get install -y \
    php8.2 \
    php8.2-fpm \
    php8.2-mysqli \
    # ... other extensions
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Copy Configs
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY conf/custom.ini /etc/php/8.2/fpm/conf.d/99-custom.ini

# Setup Entrypoint
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Directory Setup
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html && \
    mkdir -p /run/php && \
    chown -R www-data:www-data /run/php

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm8.2", "-F"]
`

- **Stack**: Uses the latest stable PHP 8.2 stack.
- **WP-CLI**: Manually installs WP-CLI to facilitate automated WordPress installation in the entrypoint.
- **Configuration**: Overrides default PHP-FPM settings to listen on a network port instead of a socket.
- **Runtime Setup**: Ensures /run/php exists, which is required for PHP-FPM to start.

## 5. Operational Details

### Expected Runtime Behavior
1. **Wait for DB**: Entrypoint loops and waits until it can connect to the MariaDB host.
2. **Install/Configure**: 
   - Checks if wp-config.php exists.
   - If not, downloads WordPress core.
   - Generates config connecting to the DB.
   - Installs WordPress (creates tables, admin user).
   - Creates an additional author user.
3. **Start Server**: Starts php-fpm8.2 in foreground mode (-F).

### Logging
- **PHP Logs**: Directed to /var/log/php8.2-fpm.log (configured in www.conf).
- **Access/Error**: Configured to log errors to stderr (log_errors = on).

### Common Troubleshooting
- **Database Connection Error**: If WordPress cannot connect to MariaDB, check credentials and ensure MariaDB container is healthy.
- **Permissions**: If plugins/uploads fail, check ownership of /var/www/html (should be www-data).
- **White Screen**: Check PHP error logs.

## 6. Architectural Context

### Diagram
`mermaid
graph TD
    Nginx[Nginx] -- FastCGI:9000 --> WP[WordPress]
    WP -- TCP:3306 --> DB[MariaDB]
    WP -- Reads/Writes --> Volume[WordPress Volume]
`

### Communication
- **Inbound**: Accepts FastCGI connections on TCP 9000 from Nginx.
- **Outbound**: Initiates TCP connections to MariaDB on port 3306.

### Performance & Scaling
- **PHP-FPM Tuning**: pm.max_children, pm.start_servers in www.conf control how many concurrent requests can be handled.
- **Memory**: PHP memory limit is increased to 512M to handle resource-intensive themes or plugins.
