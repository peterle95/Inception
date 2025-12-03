# WordPress Service

This container runs WordPress with PHP-FPM, serving dynamic content for the Inception project.

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [Dockerfile Breakdown](#dockerfile-breakdown)
- [PHP Configuration Files](#php-configuration-files)
- [How It Works](#how-it-works)
- [Integration with Other Services](#integration-with-other-services)

## Overview

WordPress is a popular content management system (CMS) written in PHP. In this project:
- WordPress runs with **PHP-FPM** (FastCGI Process Manager)
- Serves dynamic content on port **9000**
- Connects to **MariaDB** for data storage
- Receives requests from **NGINX** via FastCGI protocol

## Configuration

- **Base Image**: Alpine Linux 3.19
- **PHP Version**: PHP 8.1 with FPM
- **Port**: 9000 (FastCGI, internal network only)
- **Working Directory**: `/var/www/html`
- **Tool**: WP-CLI for WordPress management

### Environment Variables

From `.env` file:
- `DOMAIN_NAME` - WordPress site URL
- `MYSQL_DATABASE` - Database name
- `MYSQL_USER` - Database user
- `WP_ADMIN_USER` - WordPress admin username
- `WP_ADMIN_EMAIL` - WordPress admin email
- `WP_USER` - WordPress normal user username
- `WP_USER_EMAIL` - WordPress normal user email

From Docker secrets:
- `MYSQL_PASSWORD` - Database password
- `WP_ADMIN_PASSWORD` - WordPress admin password
- `WP_USER_PASSWORD` - WordPress normal user password

## Dockerfile Breakdown

```dockerfile
FROM alpine:3.19
```
- **Base Image**: Alpine Linux 3.19 (minimal, lightweight)
- Benefits: Small size, security-focused

```dockerfile
RUN apk update && apk add --no-cache \
    php81 \
    php81-fpm \
    php81-mysqli \
    php81-phar \
    php81-iconv \
    php81-mbstring \
    php81-openssl \
    curl \
    mariadb-client
```
- **PHP packages**:
  - `php81` - PHP 8.1 runtime
  - `php81-fpm` - FastCGI Process Manager
  - `php81-mysqli` - MySQL/MariaDB extension for database connectivity
  - `php81-phar` - PHP Archive support (needed for WP-CLI)
  - `php81-iconv`, `php81-mbstring` - Character encoding support
  - `php81-openssl` - SSL/TLS support
- **Tools**:
  - `curl` - For downloading WP-CLI
  - `mariadb-client` - For testing database connectivity

```dockerfile
RUN ln -s /usr/bin/php81 /usr/bin/php
```
- **Symlink**: Creates `php` command pointing to `php81`
- Allows scripts to use `#!/usr/bin/env php`

```dockerfile
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp
```
- **WP-CLI Installation**: WordPress command-line tool
- Used in entrypoint for automated WordPress setup

```dockerfile
COPY conf/www.conf /etc/php81/php-fpm.d/www.conf
COPY conf/custom.ini /etc/php81/conf.d/custom.ini
```
- **Custom PHP configuration files**:
  - `www.conf` - PHP-FPM pool configuration
  - `custom.ini` - PHP runtime settings
- **Benefits**: Explicit, version-controlled configuration (no runtime sed modifications)

```dockerfile
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
```
- **Entrypoint script**: Handles WordPress installation and configuration

```dockerfile
WORKDIR /var/www/html
EXPOSE 9000
```
- **Working directory**: WordPress installation location
- **Port 9000**: PHP-FPM listens for FastCGI connections from NGINX

```dockerfile
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm81", "-F"]
```
- **Entrypoint**: Runs initialization (downloads and configures WordPress)
- **CMD**: Starts PHP-FPM in foreground mode (`-F`)

## PHP Configuration Files

### www.conf - PHP-FPM Pool Configuration

File: [conf/www.conf](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\requirements\wordpress\conf\www.conf)

**Key settings**:
- `listen = 9000` - Listen on all interfaces (Docker networking)
- `user = nobody` - Run as non-root user
- `pm = dynamic` - Dynamic process management
- `pm.max_children = 5` - Maximum worker processes
- `pm.start_servers = 2` - Initial workers on startup
- `request_terminate_timeout = 300` - 5-minute timeout for long requests

**Why?** Default configuration binds to `127.0.0.1:9000`, which doesn't work for Docker container-to-container communication.

### custom.ini - PHP Runtime Configuration

File: [conf/custom.ini](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\requirements\wordpress\conf\custom.ini)

**Key settings**:
- `memory_limit = 512M` - Increased from default 128M (WordPress needs more memory)
- `max_execution_time = 300` - 5 minutes for long operations
- `post_max_size = 64M` - Large POST data support
- `upload_max_filesize = 64M` - Large file uploads (images, media)
- `max_file_uploads = 20` - Multiple file uploads
- `display_errors = Off` - Security (don't expose errors to users)
- `log_errors = On` - Log errors for debugging

**Benefits**: Optimized for WordPress performance and media handling.

## How It Works

### Startup Sequence

1. **Container starts** → `entrypoint.sh` executed
2. **Wait for MariaDB** → Ping database until ready
3. **Download WordPress** → If not already installed
4. **Configure WordPress**:
   - Create `wp-config.php` with database credentials
   - Set site URL
   - Install WordPress core
5. **Create users**:
   - Admin user (from secrets)
   - Normal user (from secrets)
6. **Start PHP-FPM** → Listen on port 9000 for FastCGI requests

### Request Flow

```
User Browser
    ↓
NGINX (443/HTTPS)
    ↓ FastCGI
PHP-FPM (9000)
    ↓ Execute PHP
WordPress
    ↓ SQL Query
MariaDB (3306)
    ↓ Results
WordPress
    ↓ HTML
NGINX
    ↓ HTTPS
User Browser
```

## Integration with Other Services

### NGINX Connection

NGINX communicates with WordPress via **FastCGI protocol**:

```nginx
# From nginx.conf
location ~ \.php$ {
    fastcgi_pass wordpress:9000;
    fastcgi_index index.php;
    include /etc/nginx/fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}
```

- **DNS**: Docker resolves `wordpress` to container IP
- **Port 9000**: PHP-FPM listening port
- **FastCGI**: Binary protocol for efficient PHP execution

### MariaDB Connection

WordPress connects to MariaDB via **mysqli**:

```php
// In wp-config.php (generated by entrypoint)
define('DB_NAME', 'wordpress');
define('DB_USER', 'wpuser');
define('DB_PASSWORD', '...');
define('DB_HOST', 'mariadb:3306');
```

- **Host**: `mariadb` (Docker DNS)
- **Port**: 3306 (standard MySQL/MariaDB port)
- **Protocol**: MySQL wire protocol

---

**Related Documentation**:
- [Main Project README](file:///\\wsl.localhost\\Ubuntu\\home\\ubuntu\\Inception-final\\README.md)
- [WordPress Testing Guide](file:///\\wsl.localhost\\Ubuntu\\home\\ubuntu\\Inception-final\\srcs\\requirements\\wordpress\\TESTING.MD)
- [MariaDB Service README](file:///\\wsl.localhost\\Ubuntu\\home\\ubuntu\\Inception-final\\srcs\\requirements\\mariadb\\README.md)
- [NGINX Service README](file:///\\wsl.localhost\\Ubuntu\\home\\ubuntu\\Inception-final\\srcs\\requirements\\nginx\\README.md)