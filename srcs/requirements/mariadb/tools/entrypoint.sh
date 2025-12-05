#!/bin/bash
set -e

# Fix ownership of data directory (important for mounted volumes)
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /run/mysqld

# Check if the database needs to be initialized
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB temporarily to set up users
echo "Starting temporary MariaDB server for user setup..."
mysqld --user=mysql --skip-networking &
pid="$!"

# Wait for MariaDB to be ready
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