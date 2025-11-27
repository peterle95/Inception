#!/bin/sh

# Check if the database is already initialized
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

    echo "Starting temporary MariaDB server..."
    /usr/bin/mysqld --user=mysql --bootstrap << EOF
USE mysql;
FLUSH PRIVILEGES;

-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

-- Create database
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};

-- Create user
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';

-- Flush privileges
FLUSH PRIVILEGES;
EOF
    echo "Database initialized."
fi

echo "Starting MariaDB..."
exec "$@"
