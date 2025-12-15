# User Documentation - Inception Project

This document explains how to use and manage the Inception infrastructure as an end user or administrator.

## Table of Contents
- [Overview](#overview)
- [Starting and Stopping](#starting-and-stopping)
- [Accessing Services](#accessing-services)
- [Managing Credentials](#managing-credentials)
- [Verifying Services](#verifying-services)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

## Overview

### What Services Are Provided?

The Inception stack provides a complete WordPress website infrastructure with:

1. **NGINX Web Server** (Port 443)
   - Serves static files (images, CSS, JavaScript)
   - Handles HTTPS connections with TLS 1.3
   - Forwards PHP requests to WordPress
   - Acts as reverse proxy

2. **WordPress CMS** (Internal Port 9000)
   - Content management system for creating/editing website
   - Processes dynamic PHP content
   - Admin panel for site management
   - Connects to MariaDB for data storage

3. **MariaDB Database** (Internal Port 3306)
   - Stores all WordPress data (posts, users, settings)
   - Only accessible from within Docker network (not from internet)
   - Automatic backups via volume persistence

### Architecture Diagram
```
Internet
   ↓
[Host Machine: Port 443]
   ↓
[NGINX Container] ← TLS 1.3 HTTPS
   ↓
[WordPress Container] ← PHP-FPM
   ↓
[MariaDB Container] ← MySQL Protocol
   ↓
[Persistent Storage: /home/pmolzer/data/]
```

## Starting and Stopping

### Starting the Project
```bash
# Navigate to project directory
cd ~/inception

# Start all services (first time)
make

# Or if already built, just start
make up
```

**What happens:**
1. Docker builds images (if needed) - takes ~2-5 minutes first time
2. Creates Docker network for inter-container communication
3. Starts MariaDB (initializes database on first run)
4. Starts WordPress (installs WordPress on first run)
5. Starts NGINX (generates SSL certificate on first run)

**Expected output:**
```
Building containers...
Starting containers...
[+] Running 3/3
 ✔ Container mariadb    Started
 ✔ Container wordpress  Started
 ✔ Container nginx      Started
```

### Stopping the Project
```bash
# Stop all services (keeps data)
make down
```

**What happens:**
- Containers stop gracefully
- Data remains in `/home/pmolzer/data/`
- Network and volumes persist

### Restarting After System Reboot
```bash
# After VM/server reboot
cd ~/inception
make up
```

**Note:** After a reboot, containers auto-start due to `restart: always` in docker-compose.yml, but you can manually restart them with `make up` if needed.

### Checking Status
```bash
# See all running containers
docker ps

# Expected output:
# CONTAINER ID   IMAGE       STATUS          PORTS                  NAMES
# abc123         nginx       Up 2 minutes    0.0.0.0:443->443/tcp   nginx
# def456         wordpress   Up 2 minutes    9000/tcp               wordpress
# ghi789         mariadb     Up 2 minutes    3306/tcp               mariadb
```

All three containers should show `Up` status.

## Accessing Services

### Accessing the Website

**URL:** https://pmolzer.42.fr

**Browser Access:**
1. Open your web browser
2. Navigate to `https://pmolzer.42.fr`
3. Accept the self-signed certificate warning (click "Advanced" → "Proceed")
4. You'll see the WordPress homepage

**Command Line Access:**
```bash
curl -k https://pmolzer.42.fr
```

**Note:** The `-k` flag bypasses SSL verification (needed for self-signed certificates).

### Accessing the WordPress Admin Panel

**URL:** https://pmolzer.42.fr/wp-admin

**Steps:**
1. Navigate to `https://pmolzer.42.fr/wp-admin`
2. Enter admin credentials:
   - **Username:** Found in `secrets/credentials.txt` (e.g., `pmolzer`)
   - **Password:** Found in `secrets/credentials.txt` (e.g., `wpAdminSecure123!`)
3. Click "Log In"

**What you can do:**
- Create and edit blog posts
- Manage pages
- Install plugins and themes
- Manage users
- Configure site settings
- View analytics

### Accessing the Database (Administrators Only)

The database is **not accessible** from the internet for security. Administrators can access it from inside the Docker network:

**Method 1: As WordPress user (wpuser)**
```bash
docker exec -it mariadb mysql -u wpuser -p
# Enter password when prompted (from secrets/db_password.txt)
```

**Method 2: As root user**
```bash
docker exec -it mariadb mysql -u root -p
# Enter password when prompted (from secrets/db_root_password.txt)
```

**Common database commands:**
```sql
-- Show all databases
SHOW DATABASES;

-- Switch to WordPress database
USE wordpress;

-- Show all tables
SHOW TABLES;

-- View WordPress users
SELECT user_login, user_email FROM wp_users;

-- Exit
EXIT;
```

## Managing Credentials

### Location of Credentials

All sensitive credentials are stored in the `secrets/` directory:
```
secrets/
├── credentials.txt        # WordPress admin login
├── db_password.txt        # WordPress database user password
└── db_root_password.txt   # MariaDB root password
```

### Viewing Credentials
```bash
# WordPress admin credentials
cat secrets/credentials.txt

# Output:
# username=pmolzer
# password=wpAdminSecure123!

# Database passwords
cat secrets/db_password.txt
cat secrets/db_root_password.txt
```

### Changing Credentials

⚠️ **Warning:** Changing credentials requires rebuilding the stack!

**Steps:**

1. **Stop the services:**
```bash
   make down
```

2. **Edit the credential files:**
```bash
   nano secrets/db_password.txt
   nano secrets/db_root_password.txt
   nano secrets/credentials.txt
```

3. **Clear old data:**
```bash
   make fclean
```

4. **Rebuild and restart:**
```bash
   make
```

**Note:** This will reset the database and WordPress installation!

### Security Best Practices

- ✅ **Never commit `secrets/` to Git** (already in `.gitignore`)
- ✅ Use strong passwords (minimum 12 characters, mixed case, numbers, symbols)
- ✅ Don't share credentials over insecure channels (email, Slack)
- ✅ Backup credentials securely (encrypted password manager)
- ❌ Don't use default/weak passwords like `password123`

## Verifying Services

### Quick Health Check
```bash
# Check all containers are running
docker ps

# All three should show "Up" status
```

### Detailed Service Verification

#### 1. NGINX Web Server
```bash
# Check NGINX is running
docker ps | grep nginx

# View NGINX logs
docker logs nginx

# Test HTTPS connection
curl -k -I https://pmolzer.42.fr

# Expected: HTTP/2 200 OK
```

#### 2. WordPress Application
```bash
# Check WordPress is running
docker ps | grep wordpress

# View WordPress logs
docker logs wordpress

# Test WordPress is installed
docker exec -it wordpress wp core is-installed --allow-root && echo "WordPress is installed" || echo "WordPress not installed"

# List WordPress users
docker exec -it wordpress wp user list --allow-root
```

#### 3. MariaDB Database
```bash
# Check MariaDB is running
docker ps | grep mariadb

# View MariaDB logs
docker logs mariadb

# Test database connection
docker exec -it mariadb mysqladmin ping -u wpuser -p"$(cat secrets/db_password.txt)" --silent && echo "Database is responsive" || echo "Database not responding"

# Check database has content
docker exec -it mariadb mysql -u wpuser -p"$(cat secrets/db_password.txt)" wordpress -e "SELECT COUNT(*) as user_count FROM wp_users;"
```

### Network Connectivity Test
```bash
# Test NGINX can reach WordPress
docker exec -it nginx ping -c 3 wordpress

# Test WordPress can reach MariaDB
docker exec -it wordpress ping -c 3 mariadb
```

### Volume Persistence Test
```bash
# Check data directories exist and have content
ls -lh /home/pmolzer/data/mariadb
ls -lh /home/pmolzer/data/wordpress

# MariaDB data should contain database files
# WordPress data should contain WordPress installation
```

### SSL/TLS Verification
```bash
# Check TLS version
openssl s_client -connect pmolzer.42.fr:443 -tls1_3

# Should show: Protocol: TLSv1.3
# Should NOT work with TLS 1.2 or lower

# Test TLS 1.2 (should fail)
openssl s_client -connect pmolzer.42.fr:443 -tls1_2
# Expected: alert protocol version (this proves only TLS 1.3 is enabled)
```

## Common Tasks

### Creating a WordPress Post

**Via Admin Panel:**
1. Log in to https://pmolzer.42.fr/wp-admin
2. Click "Posts" → "Add New"
3. Enter title and content
4. Click "Publish"

**Via Command Line (WP-CLI):**
```bash
docker exec -it wordpress wp post create \
  --post_title="My New Post" \
  --post_content="This is the content of my post." \
  --post_status=publish \
  --allow-root
```

### Creating a WordPress User

**Via Admin Panel:**
1. Log in to admin panel
2. Navigate to "Users" → "Add New"
3. Fill in user details
4. Select role (Subscriber, Contributor, Author, Editor, Administrator)
5. Click "Add New User"

**Via Command Line:**
```bash
docker exec -it wordpress wp user create \
  newuser \
  newuser@example.com \
  --role=author \
  --user_pass=SecurePassword123! \
  --allow-root
```

### Backing Up Data
```bash
# Backup WordPress files
sudo cp -r /home/pmolzer/data/wordpress ~/backup/wordpress-$(date +%Y%m%d)

# Backup MariaDB database
docker exec mariadb mysqldump -u root -p"$(cat secrets/db_root_password.txt)" wordpress > ~/backup/wordpress-db-$(date +%Y%m%d).sql

# Backup secrets
cp -r secrets ~/backup/secrets-$(date +%Y%m%d)
```

### Restoring from Backup
```bash
# Stop services
make down

# Restore WordPress files
sudo rm -rf /home/pmolzer/data/wordpress/*
sudo cp -r ~/backup/wordpress-YYYYMMDD/* /home/pmolzer/data/wordpress/

# Restore database
cat ~/backup/wordpress-db-YYYYMMDD.sql | docker exec -i mariadb mysql -u root -p"$(cat secrets/db_root_password.txt)" wordpress

# Restore secrets
cp -r ~/backup/secrets-YYYYMMDD/* secrets/

# Restart services
make up
```

### Viewing Logs
```bash
# View logs for all services
docker compose -f srcs/docker-compose.yml logs

# Follow logs in real-time
docker compose -f srcs/docker-compose.yml logs -f

# View specific service logs
docker logs nginx
docker logs wordpress
docker logs mariadb

# View last 50 lines
docker logs mariadb --tail 50
```

### Updating WordPress
```bash
# Check for updates
docker exec -it wordpress wp core check-update --allow-root

# Update WordPress core
docker exec -it wordpress wp core update --allow-root

# Update all plugins
docker exec -it wordpress wp plugin update --all --allow-root

# Update all themes
docker exec -it wordpress wp theme update --all --allow-root
```

## Troubleshooting

### Problem: Cannot access website (Connection refused)

**Symptoms:**
- Browser shows "Connection refused"
- `curl -k https://pmolzer.42.fr` fails

**Solution:**
```bash
# Check if containers are running
docker ps

# If containers are down, start them
make up

# Check NGINX logs for errors
docker logs nginx

# Verify port 443 is open
sudo netstat -tlnp | grep 443
```

### Problem: 502 Bad Gateway

**Symptoms:**
- NGINX shows "502 Bad Gateway" error
- Website loads NGINX page but not WordPress

**Causes:**
- WordPress container not running
- WordPress PHP-FPM not started

**Solution:**
```bash
# Check WordPress is running
docker ps | grep wordpress

# Check WordPress logs
docker logs wordpress

# Restart WordPress
docker restart wordpress

# Verify WordPress is listening
docker exec -it nginx nc -zv wordpress 9000
```

### Problem: 403 Forbidden

**Symptoms:**
- NGINX shows "403 Forbidden"
- Cannot access website files

**Cause:** Permission issue on WordPress files

**Solution:**
```bash
# Fix permissions
make down
sudo chown -R 33:33 /home/pmolzer/data/wordpress
sudo chmod -R 755 /home/pmolzer/data/wordpress
make up
```

### Problem: Database connection error

**Symptoms:**
- "Error establishing database connection" in WordPress
- WordPress logs show connection failures

**Solutions:**

**Check 1: MariaDB is running**
```bash
docker ps | grep mariadb
docker logs mariadb
```

**Check 2: Database credentials are correct**
```bash
# Verify credentials
cat secrets/db_password.txt

# Test database connection manually
docker exec -it wordpress mysqladmin ping -h mariadb -u wpuser -p"$(cat secrets/db_password.txt)"
```

**Check 3: Network connectivity**
```bash
# Test WordPress can reach MariaDB
docker exec -it wordpress ping mariadb
```

**Fix: Restart MariaDB**
```bash
docker restart mariadb
# Wait 10 seconds
docker restart wordpress
```

### Problem: WordPress not installing

**Symptoms:**
- WordPress container keeps restarting
- Logs show "Waiting for MariaDB..." infinitely

**Solution:**
```bash
# Check MariaDB is fully ready
docker logs mariadb | grep "ready for connections"

# If not ready, check MariaDB errors
docker logs mariadb

# Common fix: Reset database
make fclean
make
```

### Problem: SSL certificate warning

**Symptoms:**
- Browser shows "Your connection is not private"
- Certificate error

**Explanation:** This is **expected behavior** because we use a self-signed certificate.

**Solution:**
```bash
# In browser: Click "Advanced" → "Proceed to pmolzer.42.fr (unsafe)"

# This is safe for local development/testing
# For production, you'd use Let's Encrypt or a commercial certificate
```

### Problem: Containers won't start after reboot

**Symptoms:**
- Containers in restart loop after VM reboot
- `docker ps` shows "Restarting"

**Solution:**
```bash
# Stop all containers
make down

# Fix permissions (common issue after reboot)
sudo chown -R 999:999 /home/pmolzer/data/mariadb
sudo chown -R 33:33 /home/pmolzer/data/wordpress

# Start again
make up

# Monitor logs
docker logs -f mariadb
```

### Problem: Out of disk space

**Check disk usage:**
```bash
# Check volume sizes
docker system df

# Check data directory size
du -sh /home/pmolzer/data/*
```

**Clean up:**
```bash
# Remove unused images and containers
make clean

# Full cleanup (WARNING: deletes all data!)
make fclean
```

### Getting Help

**View container logs:**
```bash
# All logs
docker compose -f srcs/docker-compose.yml logs

# Specific service
docker logs nginx --tail 100
```

**Interactive debugging:**
```bash
# Access container shell
docker exec -it nginx bash
docker exec -it wordpress bash
docker exec -it mariadb bash
```

**Check Docker status:**
```bash
# Docker info
docker info

# Network inspection
docker network inspect srcs_inception

# Volume inspection
docker volume ls
```

## Maintenance Schedule

### Daily
- ✅ Check all containers are running: `docker ps