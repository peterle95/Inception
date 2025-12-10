#!/bin/bash
set -e

# Read secrets from Docker secrets files (with fallback to env vars)
# -f means if the file exists
if [ -f /run/secrets/db_password ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
    export MYSQL_PASSWORD
fi # fi means end of the if statement

if [ -f /run/secrets/db_root_password ]; then
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
    export MYSQL_ROOT_PASSWORD
fi

# Fix ownership of data directory (important for mounted volumes)
# chown gives permissions to users while chmod changes permissions to files
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /run/mysqld

# Check if the database needs to be initialized
# "! -d" means if the directory does not exist 
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB temporarily to set up users
echo "Starting temporary MariaDB server for user setup..."
mysqld --user=mysql --skip-networking &
pid="$!"

# Wait for MariaDB to be ready
# here we are waiting for the database to start
# if it doesn't start in 30 seconds, the container will exit
# if it starts, we will continue to the next step
echo "Waiting for MariaDB to start..."
for i in {1..30}; do
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
kill "$pid"
wait "$pid" 2>/dev/null || true

echo "Starting MariaDB..."
exec "$@"