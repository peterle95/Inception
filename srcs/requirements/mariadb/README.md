# MariaDB Service

This container provides the MariaDB database server for the Inception WordPress infrastructure.

## Table of Contents

- [What is MariaDB?](#what-is-mariadb)
- [Why MariaDB in This Project?](#why-mariadb-in-this-project)
- [How It Works](#how-it-works)
- [Dockerfile Breakdown](#dockerfile-breakdown)
- [Entrypoint Script Breakdown](#entrypoint-script-breakdown)
- [Integration with Other Services](#integration-with-other-services)
- [Configuration Details](#configuration-details)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

## What is MariaDB?

**MariaDB** is an open-source relational database management system (RDBMS) that is a fork of MySQL. It was created by the original developers of MySQL after concerns about Oracle's acquisition of MySQL.

### Key Features

- **MySQL Compatible**: Drop-in replacement for MySQL with the same APIs and protocols
- **Open Source**: Completely free and open-source (GPL licensed)
- **Performance**: Optimized query execution and improved storage engines
- **Security**: Enhanced security features and regular security updates
- **Community Driven**: Active development community with transparent development process

### Why MariaDB vs MySQL?

- Truly open-source (MySQL is owned by Oracle)
- Better performance in many scenarios
- More storage engines available
- Active community development
- More transparent security vulnerability handling

## Why MariaDB in This Project?

This project uses MariaDB for several specific reasons:

### 1. **Project Requirements**
The Inception project specifically requires a dedicated database container for WordPress. MariaDB fulfills this requirement perfectly as WordPress officially supports it.

### 2. **Alpine Linux Compatibility**
MariaDB has excellent support in Alpine Linux (our base image), with:
- Small package size (minimal disk footprint)
- Easy installation via `apk`
- Well-maintained Alpine packages

### 3. **Lightweight and Fast**
For a containerized environment:
- Lower memory footprint than PostgreSQL
- Faster startup times
- Efficient resource usage in Docker

### 4. **WordPress Compatibility**
WordPress officially supports MariaDB and uses it interchangeably with MySQL:
- Same database schema
- Compatible SQL syntax
- Seamless integration via mysqli PHP extension

### 5. **Docker Best Practices**
- Runs as a non-root user (`mysql`)
- Single-purpose container (only database, no web server)
- Easy to configure via environment variables

## How It Works

### Architecture Overview

```
┌─────────────────────────────────────────┐
│         MariaDB Container               │
│                                         │
│  ┌────────────────────────────────┐    │
│  │   Entrypoint Script            │    │
│  │   /usr/local/bin/entrypoint.sh │    │
│  └──────────┬─────────────────────┘    │
│             │                           │
│             ▼                           │
│  ┌─────────────────────────┐           │
│  │  First Run Check        │           │
│  │  /var/lib/mysql/mysql   │           │
│  │  exists?                │           │
│  └──────┬──────────┬───────┘           │
│         │          │                   │
│    NO   │          │ YES               │
│         ▼          ▼                   │
│  ┌──────────┐  ┌─────────┐            │
│  │Initialize│  │  Skip   │            │
│  │ Database │  │  Setup  │            │
│  └──────┬───┘  └────┬────┘            │
│         │           │                  │
│         └───────┬───┘                  │
│                 ▼                      │
│  ┌─────────────────────────────────┐  │
│  │  mysqld --user=mysql            │  │
│  │  Listening on 0.0.0.0:3306      │  │
│  └─────────────────────────────────┘  │
│                                        │
│  Volume: /var/lib/mysql ──────────────┼──▶ Host: /home/pmolzer/data/mariadb
│                                        │
└────────────────────────────────────────┘
```

### Startup Sequence

1. **Container starts** → `entrypoint.sh` executed
2. **Check for existing database** → Look for `/var/lib/mysql/mysql` directory
3. **If first run**:
   - Initialize MariaDB data directory
   - Start temporary server in bootstrap mode
   - Create root user with password from secrets
   - Create WordPress database
   - Create WordPress user with privileges
   - Stop temporary server
4. **Start MariaDB daemon** → `mysqld --user=mysql`
5. **Listen for connections** → Accept TCP connections on port 3306

## Dockerfile Breakdown

Let's examine each part of the [Dockerfile](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\requirements\mariadb\Dockerfile):

```dockerfile
FROM alpine:3.19
```
- **Base Image**: Alpine Linux 3.19 (minimal, security-focused distribution)
- **Size**: ~5MB base image (vs ~120MB for debian:slim)
- **Benefits**: Small attack surface, fast downloads, quick container startup

```dockerfile
RUN apk update && apk add --no-cache mariadb mariadb-client
```
- **Installed Packages**:
  - `mariadb` - MariaDB server (mysqld binary and libraries)
  - `mariadb-client` - Client tools (mysql, mysqldump, mysqladmin)
- **Why both?**: Server for hosting database, client for initialization and testing
- **`--no-cache`**: Don't save package index (keeps image smaller)

```dockerfile
RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld
```
- **Creates runtime directory**: MariaDB socket file and PID file location
- **Ownership**: Owned by `mysql` user (MariaDB runs as non-root)
- **Required**: mysqld fails to start without this directory

```dockerfile
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
```
- **Copies initialization script** from host to container
- **Makes executable**: Sets execute permissions
- **Purpose**: Handles database initialization before starting MariaDB

```dockerfile
COPY conf/50-server.cnf /etc/my.cnf.d/50-server.cnf
```
- **Copies custom configuration**: Dedicated MariaDB configuration file
- **File location**: [conf/50-server.cnf](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\requirements\mariadb\conf\50-server.cnf)
- **Key settings**:
  - `bind-address = 0.0.0.0` - Listen on all network interfaces
  - `skip-name-resolve` - Performance optimization (skip DNS)
  - `character-set-server = utf8mb4` - Full Unicode support
  - `user = mysql` - Run as non-root user
- **Why dedicated config?**: More maintainable than inline sed modifications
- **Result**: WordPress container can connect via `mariadb:3306`

```dockerfile
EXPOSE 3306
```
- **Documents port**: Informs Docker that container listens on port 3306
- **Not a firewall rule**: Doesn't actually publish the port
- **Published in docker-compose.yml**: Port is internal to Docker network only

```dockerfile
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mysqld", "--user=mysql"]
```
- **ENTRYPOINT**: Always runs `entrypoint.sh` first (initialization logic)
- **CMD**: Passed as arguments (`$@`) to entrypoint script
- **Execution**: `entrypoint.sh` runs, then executes `mysqld --user=mysql`
- **PID 1**: Final `exec "$@"` ensures mysqld becomes PID 1 (proper signal handling)

## Entrypoint Script Breakdown

Let's examine [entrypoint.sh](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\requirements\mariadb\tools\entrypoint.sh) line by line:

```bash
#!/bin/sh
```
- **Shebang**: Use `/bin/sh` (POSIX shell, not bash)
- **Why?**: Alpine uses BusyBox sh (smaller than bash)

```bash
if [ ! -d "/var/lib/mysql/mysql" ]; then
```
- **First-run check**: `/var/lib/mysql/mysql` is created by `mysql_install_db`
- **Logic**: If this directory doesn't exist, database needs initialization
- **Idempotent**: Safe to run multiple times (only initializes once)

```bash
echo "Initializing database..."
mysql_install_db --user=mysql --datadir=/var/lib/mysql
```
- **Initializes MariaDB**: Creates system database and tables
- **Creates**:
  - `mysql` database (user accounts, privileges)
  - `performance_schema` database (monitoring)
  - `test` database
  - System tables (user, db, tables_priv, etc.)
- **`--user=mysql`**: Ownership set to mysql user
- **`--datadir=/var/lib/mysql`**: Where to create database files

```bash
echo "Starting temporary MariaDB server..."
/usr/bin/mysqld --user=mysql --bootstrap <<EOF
```
- **Bootstrap mode**: Starts MariaDB in single-user mode (no TCP listening)
- **Purpose**: Execute SQL commands for initial setup
- **Heredoc (`<<EOF`)**: SQL commands piped to stdin
- **Why temporary?**: Need to create users/databases before normal startup

```sql
USE mysql;
FLUSH PRIVILEGES;
```
- **Switch to mysql database**: System database for user accounts
- **FLUSH PRIVILEGES**: Reload grant tables (ensure changes take effect)

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
```
- **Sets root password**: Read from environment variable
- **Source**: Docker secret mounted at `/run/secrets/db_root_password`
- **Why?**: Default MariaDB has no root password (security risk)
- **`@'localhost'`**: Root can only connect from localhost (inside container)

```sql
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
```
- **Creates WordPress database**: Named from `MYSQL_DATABASE` env var
- **`IF NOT EXISTS`**: Idempotent (won't error if already exists)
- **Default value**: `wordpress` (from `.env` file)

```sql
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
```
- **Creates WordPress user**: Username from `MYSQL_USER` env var
- **`@'%'`**: Can connect from any host (necessary for WordPress container)
- **Password**: Read from `MYSQL_PASSWORD` env var (from Docker secret)
- **Grants all privileges**: On WordPress database only (not system databases)
- **Principle of least privilege**: WordPress can't access mysql database

```sql
FLUSH PRIVILEGES;
EOF
```
- **Reloads grant tables**: Ensures all privilege changes take effect
- **Ends heredoc**: No more SQL commands

```bash
echo "Database initialized."
fi
```
- **Completes initialization block**
- **Logs completion**: Helpful for debugging startup issues

```bash
echo "Starting MariaDB..."
exec "$@"
```
- **`exec "$@"`**: Replace current process with `mysqld --user=mysql`
- **Why `exec`?**: Makes mysqld PID 1 (proper signal handling for Docker)
- **`"$@"`**: Expands to CMD from Dockerfile: `mysqld --user=mysql`
- **Result**: Container runs mysqld as main process

## Integration with Other Services

### How WordPress Connects to MariaDB

```
WordPress Container                    MariaDB Container
┌────────────────────┐                ┌─────────────────────┐
│                    │                │                     │
│  wp-config.php     │   TCP 3306     │   mysqld            │
│  ┌──────────────┐  │   ──────────▶  │   Listening on      │
│  │ DB_HOST:     │  │                │   0.0.0.0:3306      │
│  │ mariadb:3306 │  │                │                     │
│  │              │  │   Query        │                     │
│  │ DB_NAME:     │  │   ──────────▶  │   Database:         │
│  │ wordpress    │  │                │   wordpress         │
│  │              │  │   Response     │                     │
│  │ DB_USER:     │  │   ◀──────────  │   User:             │
│  │ wpuser       │  │                │   wpuser@%          │
│  │              │  │                │                     │
│  │ DB_PASSWORD  │  │                │   Password:         │
│  │ (secret)     │  │                │   (from secret)     │
│  └──────────────┘  │                │                     │
└────────────────────┘                └─────────────────────┘
```

### Connection Details

1. **WordPress uses mysqli extension** (PHP)
2. **Connection string**:
   - Host: `mariadb` (Docker network DNS resolution)
   - Port: `3306` (default MySQL/MariaDB port)
   - Database: `wordpress` (created in entrypoint.sh)
   - User: `wpuser` (created in entrypoint.sh)
   - Password: From `/run/secrets/db_password`

3. **Network**: Both containers on `inception` bridge network
4. **DNS**: Docker resolves `mariadb` hostname to container IP

### Data Flow Example

1. **User visits** `https://pmolzer.42.fr/`
2. **NGINX receives request** → forwards to WordPress (PHP-FPM)
3. **WordPress executes PHP** → needs to fetch posts from database
4. **WordPress connects to MariaDB**:
   ```php
   mysqli_connect('mariadb', 'wpuser', $password, 'wordpress', 3306)
   ```
5. **MariaDB authenticates** → Checks user credentials
6. **WordPress sends SQL query**:
   ```sql
   SELECT * FROM wp_posts WHERE post_status='publish' ORDER BY post_date DESC;
   ```
7. **MariaDB returns results** → WordPress processes data
8. **WordPress generates HTML** → Returns to NGINX → Client

### Dependency Management

In [docker-compose.yml](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\docker-compose.yml):

```yaml
wordpress:
  depends_on:
    - mariadb
```

- **Startup order**: MariaDB starts before WordPress
- **Not a readiness check**: `depends_on` only ensures start order
- **WordPress handles waiting**: Entrypoint script tests MariaDB connection

```bash
# From wordpress entrypoint.sh
while ! mysqladmin ping -h"mariadb" --silent; do
    echo "Waiting for MariaDB..."
    sleep 2
done
```

## Configuration Details

### Network Configuration

- **Port**: 3306 (standard MariaDB/MySQL port)
- **Bind Address**: `0.0.0.0` (all interfaces within container)
- **Firewall**: Not exposed to host (only on internal Docker network)
- **Access**: Only accessible from containers on `inception` network

### Volume Configuration

- **Container Path**: `/var/lib/mysql`
- **Host Path**: `/home/pmolzer/data/mariadb`
- **Purpose**: Persistent storage for database files
- **Contents**:
  - `mysql/` - System database
  - `wordpress/` - WordPress database
  - `ib_logfile*` - InnoDB transaction logs
  - `ibdata1` - InnoDB system tablespace

### Environment Variables

From `.env` file:
- `MYSQL_DATABASE` - Database name (e.g., `wordpress`)
- `MYSQL_USER` - WordPress database user (e.g., `wpuser`)

From Docker secrets:
- `MYSQL_ROOT_PASSWORD` - Read from `/run/secrets/db_root_password`
- `MYSQL_PASSWORD` - Read from `/run/secrets/db_password`

### MariaDB Configuration File

Custom configuration file copied during image build:
- **File**: `/etc/my.cnf.d/50-server.cnf`
- **Source**: [conf/50-server.cnf](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\requirements\mariadb\conf\50-server.cnf)
- **Key settings**:
  - `bind-address = 0.0.0.0` - Listen on all network interfaces
  - `skip-name-resolve` - Skip DNS resolution for better performance
  - `user = mysql` - Run as non-root user
  - `port = 3306` - Standard MariaDB/MySQL port
  - `character-set-server = utf8mb4` - Full UTF-8 4-byte character support
  - `collation-server = utf8mb4_general_ci` - Case-insensitive collation
- **Benefits**: Version-controlled, explicit configuration following Infrastructure as Code best practices

## Security Considerations

### 1. **Non-Root User**
- MariaDB runs as `mysql` user (UID/GID created by Alpine package)
- Directory ownership: `/run/mysqld` and `/var/lib/mysql` owned by `mysql`
- Security benefit: Limits damage if container is compromised

### 2. **Network Isolation**
- **Not exposed to host**: Port 3306 not published in docker-compose.yml
- **Internal only**: Accessible only from `inception` Docker network
- **No public access**: Cannot connect from internet or host machine

### 3. **Secrets Management**
- **Passwords not in Dockerfile**: No hardcoded credentials
- **Docker secrets**: Passwords mounted as read-only files
- **Environment variables**: Only non-sensitive config (database names, usernames)

### 4. **Least Privilege**
- **WordPress user**: Only has access to `wordpress` database
- **No SUPER privilege**: Cannot modify system tables or create users
- **Root access**: Restricted to `localhost` only (within container)

### 5. **User Access Patterns**
```sql
-- Root user (admin tasks only)
'root'@'localhost' - IDENTIFIED BY password - ALL PRIVILEGES

-- WordPress user (application access)
'wpuser'@'%' - IDENTIFIED BY password - ALL ON wordpress.* ONLY
```

### Security Best Practices Applied

✅ Minimal base image (Alpine)  
✅ Non-root execution  
✅ Network isolation  
✅ Secrets management  
✅ Least privilege access  
✅ No unnecessary packages  
✅ Configuration hardening  

## Troubleshooting

### Container won't start

**Check logs**:
```bash
docker logs mariadb
```

**Common issues**:
- Permission errors on `/var/lib/mysql`
- Missing secrets files
- Invalid environment variables

### "Can't connect to MySQL server"

**From WordPress container**:
```bash
# Test DNS resolution
docker exec wordpress ping mariadb

# Test connection
docker exec wordpress mysqladmin ping -h mariadb

# Check if port is open
docker exec wordpress nc -zv mariadb 3306
```

**From host machine**:
```bash
# This should FAIL (port not exposed)
mysql -h 127.0.0.1 -P 3306 -u wpuser -p
```

### Permission denied errors

**Check volume permissions**:
```bash
ls -la /home/pmolzer/data/mariadb/
```

**Fix permissions** (if needed):
```bash
# Stop container
docker stop mariadb

# Fix ownership (mysql user in container)
docker run --rm -v /home/pmolzer/data/mariadb:/data alpine chown -R 100:101 /data

# Restart
docker start mariadb
```

### Database not initialized

**Re-initialize** (WARNING: destroys data):
```bash
# Stop and remove container
docker stop mariadb && docker rm mariadb

# Clear data directory
sudo rm -rf /home/pmolzer/data/mariadb/*

# Restart (will initialize fresh database)
make up
```

### Connect to database for debugging

**Root access** (from within container):
```bash
docker exec -it mariadb mysql -u root -p
# Enter password from secrets/db_root_password.txt
```

**WordPress user access**:
```bash
docker exec -it mariadb mysql -u wpuser -p wordpress
# Enter password from secrets/db_password.txt
```

**Useful SQL commands**:
```sql
-- Show all databases
SHOW DATABASES;

-- Use WordPress database
USE wordpress;

-- Show all tables
SHOW TABLES;

-- Show users
SELECT User, Host FROM mysql.user;

-- Show grants for WordPress user
SHOW GRANTS FOR 'wpuser'@'%';

-- Check WordPress tables
SELECT COUNT(*) FROM wp_posts;
```

### High CPU or memory usage

**Check query performance**:
```bash
docker exec mariadb mysqladmin -u root -p processlist
```

**Monitor container resources**:
```bash
docker stats mariadb
```

### Backup and restore

**Backup database**:
```bash
docker exec mariadb mysqldump -u root -p$(cat secrets/db_root_password.txt) wordpress > backup.sql
```

**Restore database**:
```bash
docker exec -i mariadb mysql -u root -p$(cat secrets/db_root_password.txt) wordpress < backup.sql
```

---

**Related Documentation**:
- [Main Project README](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\README.md)
- [MariaDB Testing Guide](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\requirements\mariadb\TESTING.MD)
- [Docker Compose Configuration](file:///\\wsl.localhost\Ubuntu\home\ubuntu\Inception-final\srcs\docker-compose.yml)