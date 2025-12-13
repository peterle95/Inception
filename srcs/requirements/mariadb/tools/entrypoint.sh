#!/bin/bash
# Shebang is necessary so that the system knows to use bash to execute the script   

# set -e is used to exit the script if a command fails
# What it does: Exit immediately if any command returns a non-zero status (fails).
# Why: Safety mechanism. 
# If MariaDB installation fails, we don't want to continue and pretend everything is okay. 
# The container should crash and restart.
set -e

# Read secrets from Docker secrets files (with fallback to env vars)
# -f tests if this is a regular file (not a directory or symlink)
if [ -f /run/secrets/db_password ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
    export MYSQL_PASSWORD
fi # fi means end of the if statement (bash syntax)

if [ -f /run/secrets/db_root_password ]; then
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
    export MYSQL_ROOT_PASSWORD
fi

# Fix ownership of data directory (important for mounted volumes)
# chown gives permissions to users while chmod changes permissions to files
# What it does: Recursively changes ownership of /var/lib/mysql to user mysql and group mysql.
# Why:
# /var/lib/mysql is where MariaDB stores all database files
# This directory is a volume mount from the host (/home/pmolzer/data/mariadb)
# When Docker mounts volumes, ownership might be wrong (could be root)
# MariaDB server runs as the mysql user and MUST be able to write to this directory
# -R means recursive - affects all files and subdirectories
# Without this: MariaDB would crash with "Permission denied" errors when trying to write data.
chown -R mysql:mysql /var/lib/mysql
# What it does: Recursively changes ownership of /run/mysqld to mysql:mysql.
# Why:
# /run/mysqld stores the MariaDB socket file (mysqld.sock)
# The socket file is used for local connections to the database
# The mysql user must be able to create and write to this directory
chown -R mysql:mysql /run/mysqld

# Check if the database needs to be initialized
# "! -d" checks if the directory does not exist
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB temporarily to set up users
# What it does: Starts the MariaDB server daemon in the background with special flags.
# Why:
# Problem: We need to run SQL commands to create users/databases, but SQL commands require a running server
# Solution: Start MariaDB temporarily, configure it, then stop it
# mysqld is the MariaDB server daemon
# --user=mysql runs the server as the mysql user
# --skip-networking CRITICAL SECURITY FLAG - disables TCP/IP connections, only allows local socket connections
# & puts the process in the background so the script can continue

# Why --skip-networking?
# During initialization, we don't want external connections
# More secure - only local connections via socket file
# Prevents anyone from connecting before we set passwords
echo "Starting temporary MariaDB server for user setup..."
mysqld --user=mysql --skip-networking &
# What it does: Saves the process ID (PID) of the background MariaDB process.
# Why:
# $! is a special bash variable that holds the PID of the last background process
# We need this PID later to kill the temporary server
# Without saving it, we wouldn't know which process to kill
pid="$!"

# Wait for MariaDB to be ready
# here we are waiting for the database to start
# if it doesn't start in 30 seconds, the container will exit
# if it starts, we will continue to the next step
echo "Waiting for MariaDB to start..."
for i in {1..30}; do
    # What it does: Attempts to ping the MariaDB server to check if it's responding.
    # Why:
    # mysqladmin ping sends a simple ping to check if MariaDB is alive
    # Returns exit code 0 if successful (server is ready)
    # --silent suppresses output messages
    # 2>/dev/null redirects error messages to the void (stderr → null device)
    # What happens:
    # If ping succeeds → MariaDB is ready → condition is true
    # If ping fails → MariaDB not ready yet → condition is false
    if mysqladmin ping --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

# Create database and user (idempotent - uses IF NOT EXISTS)
echo "Setting up database and user..."
mysql -u root <<EOF
-- Set root password (fixes issue where root accepts any password)
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
FLUSH PRIVILEGES;
EOF

echo "Database setup complete."

# Stop the temporary server
# We're done configuring - don't need the temporary server anymore
# kill (without flags) sends SIGTERM - graceful shutdown signal
# "$pid" uses the process ID we saved earlier
# MariaDB will flush buffers and shut down cleanly
kill "$pid"
# What it does: Waits for the process to finish terminating, suppressing any errors.
# Why:
# wait "$pid" blocks until the process exits
# Ensures temporary server is fully stopped before continuing
# 2>/dev/null redirects stderr (errors) to null
# || true ensures this command always succeeds (returns exit code 0)
# Without || true, if the process already died, wait would return an error and set -e would exit the script
# Why this matters: We want to guarantee the temporary server is dead before starting the real one.
wait "$pid" 2>/dev/null || true

echo "Starting MariaDB..."
exec "$@" # replaces the shell process, ensuring that the container runs as PID 1

#**What it does:** 
#- `exec` replaces the current shell process with a new command
#- `"$@"` expands to all arguments passed to the script

#**Why this is CRITICAL:**

#1. **From Dockerfile:** `CMD ["mysqld", "--user=mysql"]`
#2. **When container starts:** Docker runs: `entrypoint.sh mysqld --user=mysql`
#3. **`$@` expands to:** `mysqld --user=mysql`
#4. **`exec "$@"` becomes:** `exec mysqld --user=mysql`

#**Why `exec` instead of just running the command?**

### **The PID 1 Problem:**

#Without `exec`:
#```
#PID 1: bash (entrypoint.sh)
#  └─ PID 42: mysqld (child process)
#```
#- Docker sends signals (SIGTERM) to PID 1
#- Bash doesn't forward signals properly to children
#- MariaDB never receives shutdown signal
#- Container doesn't stop gracefully

#With `exec`:
#```
#PID 1: mysqld (replaced the bash process)
#```
#- Docker sends signals directly to MariaDB
#- MariaDB receives SIGTERM and shuts down gracefully
#- Proper signal handling
#- **This is Docker best practice**

#**In summary:** `exec` makes MariaDB the main process (PID 1), ensuring proper signal handling and clean container shutdown.

#---

## **Complete Flow Diagram**
#```
#START
#  ↓
#Read secrets from /run/secrets/
#  ↓
#Fix permissions (chown mysql:mysql)
#  ↓
#Does /var/lib/mysql/mysql/ exist?
#  ├─ NO → Run mysql_install_db (first time setup)
#  └─ YES → Skip initialization (already setup)
#  ↓
#Start MariaDB temporarily (--skip-networking)
#  ↓
#Wait loop: Is MariaDB ready?
#  ├─ Try mysqladmin ping
#  ├─ If yes → break
#  └─ If no → sleep 1 second, try again (up to 30 times)
#  ↓
#Run SQL commands:
#  ├─ Set root password
#  ├─ Create wordpress database
#  ├─ Create wpuser
#  ├─ Grant privileges
#  └─ Flush privileges
#  ↓
#Kill temporary server
#  ↓
#Wait for it to die
#  ↓
#exec mysqld (become PID 1, start real server)
#  ↓
#Container runs until stopped