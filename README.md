# Inception

A Docker-based infrastructure project that sets up a complete WordPress hosting environment with NGINX, MariaDB, and WordPress running in separate containers. This project demonstrates containerization best practices, service orchestration, and secure configuration management.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup Guide](#detailed-setup-guide)
- [Available Commands](#available-commands)
- [Project Structure](#project-structure)
- [Technical Details](#technical-details)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)

## Architecture Overview

This project implements a three-tier web application architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    Host Machine                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │         Docker Network: inception (bridge)        │  │
│  │                                                   │  │
│  │  ┌──────────────┐    ┌──────────────┐           │  │
│  │  │    NGINX     │───▶│  WordPress   │           │  │
│  │  │ (Port 443)   │    │  (PHP-FPM)   │           │  │
│  │  │  TLS 1.2/3   │    │  Port 9000   │           │  │
│  │  └──────┬───────┘    └──────┬───────┘           │  │
│  │         │                    │                   │  │
│  │         │                    ▼                   │  │
│  │         │            ┌──────────────┐            │  │
│  │         │            │   MariaDB    │            │  │
│  │         │            │  Port 3306   │            │  │
│  │         │            └──────────────┘            │  │
│  │         │                                        │  │
│  │         ▼                                        │  │
│  │  ┌──────────────┐    ┌──────────────┐           │  │
│  │  │   Volume:    │    │   Volume:    │           │  │
│  │  │  wordpress   │    │   mariadb    │           │  │
│  │  └──────────────┘    └──────────────┘           │  │
│  └───────────────────────────────────────────────────┘  │
│         │                      │                        │
│         ▼                      ▼                        │
│  /home/pmolzer/data/    /home/pmolzer/data/             │
│      wordpress/              mariadb/                   │
└─────────────────────────────────────────────────────────┘
```

### Components

- **NGINX**: Reverse proxy and TLS termination (only exposed port: 443)
- **WordPress**: PHP-FPM application server (internal port 9000)
- **MariaDB**: Database server (internal port 3306)
- **Network**: Custom Docker bridge network (`inception`) for inter-container communication
- **Volumes**: Persistent storage mounted to host directories

## How It Works

### 1. Image Building Process

When you run `make build`, the following happens:

1. **Creates data directories** on the host machine:
   - `/home/pmolzer/data/mariadb` - for database files
   - `/home/pmolzer/data/wordpress` - for WordPress files

2. **Builds custom Docker images** from Dockerfiles (NOT pulled from Docker Hub):
   - `nginx-inception` - Built from `srcs/requirements/nginx/Dockerfile`
   - `mariadb-inception` - Built from `srcs/requirements/mariadb/Dockerfile`
   - `wordpress-inception` - Built from `srcs/requirements/wordpress/Dockerfile`

Each Dockerfile:
- Starts from `alpine:3.19` base image
- Installs required packages
- Copies configuration files and entrypoint scripts
- Sets up the service to run as PID 1 (no infinite loops or hacky patches)

### 2. Container Startup Sequence

When you run `make up`, Docker Compose orchestrates the startup:

#### Step 1: Network Creation
- Creates the `inception` bridge network
- All containers join this network and can communicate using container names as hostnames

#### Step 2: Volume Mounting
- Mounts host directories to container paths:
  - `/home/pmolzer/data/mariadb` → `/var/lib/mysql` (in mariadb container)
  - `/home/pmolzer/data/wordpress` → `/var/www/html` (in nginx and wordpress containers)

#### Step 3: MariaDB Initialization
The `mariadb` container starts first (WordPress depends on it):

1. **Entrypoint script** (`entrypoint.sh`) runs:
   - Checks if database is already initialized (looks for existing data)
   - If first run:
     - Initializes MariaDB data directory
     - Starts temporary MySQL server
     - Reads secrets from `/run/secrets/`:
       - `db_root_password` - Sets root password
       - `db_password` - Sets WordPress user password
     - Creates WordPress database
     - Creates WordPress user with appropriate privileges
     - Stops temporary server
   - If already initialized, skips setup

2. **Main process** starts: `mysqld --user=mysql`
   - Runs as PID 1 (proper daemon mode)
   - Listens on `0.0.0.0:3306` (accessible within Docker network)

#### Step 4: WordPress Initialization
The `wordpress` container starts after MariaDB is ready:

1. **Entrypoint script** runs:
   - Waits for MariaDB to be ready (tests connection)
   - If WordPress not installed:
     - Downloads WordPress core using WP-CLI
     - Creates `wp-config.php` with database credentials from secrets
     - Runs WordPress installation with admin user
     - Creates additional non-admin user
   - If already installed, skips setup

2. **Main process** starts: `php-fpm81 -F`
   - Runs in foreground mode as PID 1
   - Listens on port `9000` (FastCGI)
   - Serves PHP files from `/var/www/html`

#### Step 5: NGINX Startup
The `nginx` container starts:

1. **Entrypoint script** runs:
   - Generates self-signed TLS certificate for `pmolzer.42.fr`
   - Certificate valid for 365 days
   - Uses OpenSSL with 2048-bit RSA key

2. **Main process** starts: `nginx -g "daemon off;"`
   - Runs in foreground mode as PID 1
   - Listens on port `443` (HTTPS only)
   - Configuration:
     - TLS 1.2 and 1.3 only
     - Serves static files directly
     - Proxies PHP requests to `wordpress:9000` via FastCGI
     - Document root: `/var/www/html`

### 3. Request Flow

When you visit `https://pmolzer.42.fr`:

```
1. Browser → NGINX (port 443, TLS encrypted)
2. NGINX checks request:
   - Static file (.css, .js, .jpg)? → Serve directly from /var/www/html
   - PHP file (.php)? → Forward to WordPress container via FastCGI
3. WordPress (PHP-FPM) processes PHP:
   - Executes PHP code
   - Queries MariaDB if needed (via network: wordpress → mariadb:3306)
4. MariaDB returns data to WordPress
5. WordPress returns processed content to NGINX
6. NGINX returns response to browser
```

### 4. Data Persistence

**Volumes ensure data survives container restarts:**

- **MariaDB volume**: Database tables, indexes, and data files persist in `/home/pmolzer/data/mariadb`
- **WordPress volume**: WordPress core files, themes, plugins, and uploads persist in `/home/pmolzer/data/wordpress`

When you run `make down` and `make up`, your data remains intact.

### 5. Secrets Management

Sensitive data is stored in `secrets/` directory (gitignored):

- `db_root_password.txt` - MariaDB root password
- `db_password.txt` - WordPress database user password
- `credentials.txt` - WordPress admin credentials (format: `username:password`)

Docker mounts these as read-only files in containers at `/run/secrets/`.

### 6. Environment Variables

The `.env` file (gitignored) contains non-sensitive configuration:

```env
DOMAIN_NAME=pmolzer.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
WP_TITLE=Inception
WP_ADMIN_USER=pmolzer
WP_ADMIN_EMAIL=pmolzer@student.42.fr
WP_USER=normaluser
WP_USER_EMAIL=user@student.42.fr
```

All containers have access to these variables via `env_file: .env` in docker-compose.yml.

## Prerequisites

- Docker Engine (20.10+)
- Docker Compose (2.0+)
- Root/sudo access (for editing `/etc/hosts`)
- Linux environment (WSL2 on Windows, native on Linux/Mac)

## Quick Start

```bash
# 1. Configure domain name
sudo nano /etc/hosts
# Add: 127.0.0.1 pmolzer.42.fr

# 2. Build and start
make

# 3. Access WordPress
# Open browser: https://pmolzer.42.fr
```

## Detailed Setup Guide

### Step 1: Configure Domain Name

Add the domain to your hosts file:

```bash
sudo nano /etc/hosts
```

Add this line (keep your existing entries):
```
127.0.0.1 pmolzer.42.fr
```

Save and exit (Ctrl+X, Y, Enter).

**Verify**: Test DNS resolution:
```bash
ping pmolzer.42.fr
```
You should see responses from `127.0.0.1`.

### Step 2: Build the Infrastructure

Build all Docker images from Dockerfiles:

```bash
make build
```

**What happens**:
- Creates `/home/pmolzer/data/mariadb` and `/home/pmolzer/data/wordpress`
- Builds `nginx-inception` from `srcs/requirements/nginx/Dockerfile`
- Builds `mariadb-inception` from `srcs/requirements/mariadb/Dockerfile`
- Builds `wordpress-inception` from `srcs/requirements/wordpress/Dockerfile`

**Expected output**:
```
[+] Building nginx-inception
[+] Building mariadb-inception
[+] Building wordpress-inception
```

This takes 1-3 minutes depending on your internet connection.

### Step 3: Start the Services

Start all containers:

```bash
make up
```

**What happens**:
- Creates Docker network `srcs_inception`
- Creates/mounts volumes `srcs_mariadb` and `srcs_wordpress`
- Starts containers in order: `mariadb` → `wordpress` → `nginx`

**Expected output**:
```
[+] Running 4/4
 ✔ Network srcs_inception     Created
 ✔ Container mariadb          Started
 ✔ Container wordpress        Started
 ✔ Container nginx            Started
```

### Step 4: Verify Containers Are Running

Check container status:

```bash
docker ps
```

**Expected output**:
```
CONTAINER ID   IMAGE                  COMMAND                  STATUS          PORTS
xxxxxxxxxx     nginx-inception        "/usr/local/bin/entr…"   Up X seconds    0.0.0.0:443->443/tcp
xxxxxxxxxx     mariadb-inception      "/usr/local/bin/entr…"   Up X seconds    3306/tcp
xxxxxxxxxx     wordpress-inception    "/usr/local/bin/entr…"   Up X seconds    9000/tcp
```

All three containers should be "Up".

### Step 5: Monitor WordPress Installation

Watch WordPress initialization:

```bash
docker logs -f wordpress
```

**Expected output**:
```
Waiting for MariaDB to be ready...
MariaDB is ready!
Downloading WordPress...
Success: WordPress downloaded.
Creating wp-config.php...
Success: Generated 'wp-config.php' file.
Installing WordPress...
Success: WordPress installed successfully.
Creating additional user...
Success: Created user 2.
Starting PHP-FPM...
```

Press Ctrl+C when you see "Starting PHP-FPM..." (takes ~30 seconds).

### Step 6: Access WordPress

Open your browser and navigate to:
```
https://pmolzer.42.fr
```

**What you should see**:
1. **Security Warning**: Your browser will warn about the self-signed certificate. This is expected.
   - Firefox: Click "Advanced" → "Accept the Risk and Continue"
   - Chrome: Click "Advanced" → "Proceed to pmolzer.42.fr"

2. **WordPress Homepage**: You should see the default WordPress site with the "Inception" title.

### Step 7: Login to WordPress Admin

Navigate to the admin panel:
```
https://pmolzer.42.fr/wp-admin
```

**Login credentials** (from `secrets/credentials.txt`):
- **Admin Username**: `pmolzer`
- **Admin Password**: `adminsecret123`

**What you should see**:
- WordPress admin dashboard
- Two users in the system:
  - `pmolzer` (Administrator)
  - `normaluser` (Author)

### Step 8: Verify Data Persistence

Test that data persists across restarts:

```bash
# Stop containers
make down

# Start again
make up

# Check the site - your data should still be there
```

Visit `https://pmolzer.42.fr` - the site should load with all previous data intact.

## Available Commands

| Command | Description |
|---------|-------------|
| `make` | Build and start everything (equivalent to `make all`) |
| `make build` | Build all Docker images from Dockerfiles |
| `make up` | Start all containers in detached mode |
| `make down` | Stop and remove all containers (preserves volumes) |
| `make clean` | Stop containers and prune Docker system |
| `make fclean` | Full clean (removes containers, volumes, and data directories) |
| `make re` | Rebuild everything from scratch (`fclean` + `all`) |

## Project Structure

```
.
├── Makefile                          # Build automation
├── README.md                         # This file
├── subject.txt                       # Project requirements
├── secrets/                          # Docker secrets (gitignored)
│   ├── credentials.txt               # WordPress admin credentials
│   ├── db_password.txt               # Database user password
│   └── db_root_password.txt          # Database root password
└── srcs/
    ├── .env                          # Environment variables (gitignored)
    ├── docker-compose.yml            # Service orchestration
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile            # MariaDB image definition
        │   ├── TESTING.MD            # MariaDB testing guide
        │   └── tools/
        │       └── entrypoint.sh     # MariaDB initialization script
        ├── nginx/
        │   ├── Dockerfile            # NGINX image definition
        │   ├── TESTING.MD            # NGINX testing guide
        │   ├── conf/
        │   │   └── nginx.conf        # NGINX configuration
        │   └── tools/
        │       └── entrypoint.sh     # TLS certificate generation
        └── wordpress/
            ├── Dockerfile            # WordPress image definition
            ├── TESTING.MD            # WordPress testing guide
            └── tools/
                └── entrypoint.sh     # WordPress installation script
```

## Technical Details

### Docker Images

All images are **built locally** from Dockerfiles (not pulled from Docker Hub):

#### nginx-inception
- **Base**: `alpine:3.19`
- **Packages**: `nginx`, `openssl`
- **Purpose**: Reverse proxy with TLS termination
- **Exposed Port**: 443
- **Configuration**: `/etc/nginx/http.d/default.conf`
- **Entrypoint**: Generates self-signed certificate, starts NGINX

#### mariadb-inception
- **Base**: `alpine:3.19`
- **Packages**: `mariadb`, `mariadb-client`
- **Purpose**: MySQL-compatible database server
- **Exposed Port**: 3306 (internal only)
- **Data Directory**: `/var/lib/mysql`
- **Entrypoint**: Initializes database, creates users, starts MariaDB

#### wordpress-inception
- **Base**: `alpine:3.19`
- **Packages**: `php81`, `php81-fpm`, `php81-mysqli`, `wp-cli`, `curl`
- **Purpose**: WordPress application with PHP-FPM
- **Exposed Port**: 9000 (FastCGI, internal only)
- **Working Directory**: `/var/www/html`
- **Entrypoint**: Downloads WordPress, configures, installs, starts PHP-FPM

### Network Configuration

- **Type**: Bridge network
- **Name**: `srcs_inception`
- **DNS**: Containers can resolve each other by container name
  - `nginx` can reach `wordpress:9000`
  - `wordpress` can reach `mariadb:3306`

### Volume Configuration

Both volumes use bind mounts to host directories:

```yaml
mariadb:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /home/pmolzer/data/mariadb

wordpress:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /home/pmolzer/data/wordpress
```

### Secrets Configuration

Docker secrets are mounted as read-only files in `/run/secrets/`:

```yaml
secrets:
  db_root_password:
    file: ../secrets/db_root_password.txt
  db_password:
    file: ../secrets/db_password.txt
  credentials:
    file: ../secrets/credentials.txt
```

### Container Dependencies

```yaml
wordpress:
  depends_on:
    - mariadb
```

This ensures MariaDB starts before WordPress, but doesn't guarantee MariaDB is ready. The WordPress entrypoint script includes a readiness check.

### Restart Policy

All containers have `restart: always`:
- Automatically restart on crash
- Restart on Docker daemon restart
- Restart on system reboot (if Docker is configured to start on boot)

## Troubleshooting

### Containers won't start
```bash
# Check logs for each service
docker logs nginx
docker logs mariadb
docker logs wordpress

# Check container status
docker ps -a
```

### Port 443 already in use
```bash
# Find what's using port 443
sudo lsof -i :443

# Stop the conflicting service
sudo systemctl stop <service-name>

# Or change the port in docker-compose.yml
ports:
  - "8443:443"  # Access via https://pmolzer.42.fr:8443
```

### WordPress shows "Error establishing database connection"
```bash
# Check MariaDB is running and ready
docker logs mariadb

# Check WordPress can reach MariaDB
docker exec wordpress ping mariadb

# Verify database credentials
docker exec mariadb mysql -u wpuser -p$(cat secrets/db_password.txt) -e "SHOW DATABASES;"

# Restart the stack
make down && make up
```

### Permission issues with volumes
```bash
# Check directory permissions
ls -la /home/pmolzer/data/

# Fix permissions (if needed)
sudo chown -R $USER:$USER /home/pmolzer/data/

# Clean everything and rebuild
make fclean
make all
```

### "Cannot connect to Docker daemon"
```bash
# Check Docker is running
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Add your user to docker group (to avoid sudo)
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

### Self-signed certificate warnings
This is **expected behavior**. The project uses self-signed certificates for development. For production:
- Use Let's Encrypt for free, trusted certificates
- Or import the self-signed certificate into your browser's trusted certificates

### WordPress installation hangs
```bash
# Check if MariaDB is ready
docker exec mariadb mysqladmin ping -h localhost

# Check WordPress logs
docker logs -f wordpress

# If stuck, restart WordPress container
docker restart wordpress
```

## Security Notes

### Development vs. Production

This setup is for **development/learning purposes**. For production:

1. **Use trusted TLS certificates** (Let's Encrypt)
2. **Change all default passwords**
3. **Restrict database access** (don't expose port 3306)
4. **Enable WordPress security plugins**
5. **Regular updates** (WordPress, PHP, NGINX, MariaDB)
6. **Implement backups** (database and files)
7. **Use secrets management** (HashiCorp Vault, AWS Secrets Manager)

### Current Security Measures

- ✅ All passwords stored in gitignored files (`secrets/`, `.env`)
- ✅ TLS encryption (self-signed certificate)
- ✅ Database only accessible within Docker network
- ✅ NGINX is the only service exposed to the host (port 443)
- ✅ No hardcoded credentials in Dockerfiles
- ✅ Docker secrets for sensitive data
- ✅ Minimal base images (Alpine Linux)
- ✅ Non-root user for MariaDB (`mysql`)

### Secrets Management

**Never commit these files to git**:
- `secrets/credentials.txt`
- `secrets/db_password.txt`
- `secrets/db_root_password.txt`
- `srcs/.env`

These should be in `.gitignore`:
```gitignore
secrets/
srcs/.env
```

## Data Storage

Persistent data is stored in:
- `/home/pmolzer/data/mariadb` - Database files (tables, indexes, logs)
- `/home/pmolzer/data/wordpress` - WordPress files (core, themes, plugins, uploads)

These directories are created automatically by the Makefile.

**Backup recommendations**:
```bash
# Backup database
docker exec mariadb mysqldump -u root -p$(cat secrets/db_root_password.txt) --all-databases > backup.sql

# Backup WordPress files
tar -czf wordpress-backup.tar.gz /home/pmolzer/data/wordpress/

# Restore database
docker exec -i mariadb mysql -u root -p$(cat secrets/db_root_password.txt) < backup.sql
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [MariaDB Documentation](https://mariadb.org/documentation/)
- [WordPress Documentation](https://wordpress.org/documentation/)
- [WP-CLI Documentation](https://wp-cli.org/)
- [Alpine Linux Packages](https://pkgs.alpinelinux.org/packages)

## Testing

Each service has its own testing documentation:
- [NGINX Testing Guide](srcs/requirements/nginx/TESTING.MD)
- [MariaDB Testing Guide](srcs/requirements/mariadb/TESTING.MD)
- [WordPress Testing Guide](srcs/requirements/wordpress/TESTING.MD)

---

**Project**: Inception (42 School System Administration Project)  
**Author**: pmolzer  
**Last Updated**: December 2025