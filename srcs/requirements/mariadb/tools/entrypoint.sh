#!/bin/sh
set -e

# Check if the database is already initialized
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

    # mariadb needs a temporary server to initialize the database
    # the server is started with the --bootstrap option
    # it will create the database and the user
    # then it will stop

    # mysql_install_db is a script that will create the database and the user

    # Initialize the database
    
    echo "Starting temporary MariaDB server..."
    if /usr/bin/mysqld --user=mysql --bootstrap << EOF
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
    then
        echo "Database initialized successfully."
    else
        echo "Error: Failed to initialize database."
        exit 1
    fi
else
    echo "Database already initialized."
fi

echo "Starting MariaDB..."
exec "$@"