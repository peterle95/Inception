FROM debian:bookworm

# Install MariaDB server and client
# apt-get update updates the package list
# apt-get install -y installs the packages
# && rm -rf /var/lib/apt/lists/* removes the package list (we need to do this because it takes up a lot of space)
RUN apt-get update && apt-get install -y \
    mariadb-server \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Create the run directory for mysqld
# chown gives permissions to users while chmod changes permissions to files

# RUN is used to execute commands that build and configure the image
# these commands are run when the image is built.
# Each RUN builds a new layer in the image. 
RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld
RUN mkdir -p /var/lib/mysql && chown -R mysql:mysql /var/lib/mysql

# Copy the entrypoint script and make it executable
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy the configuration file
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Expose the default MariaDB port
EXPOSE 3306

# ENTRYPOINT sets the default executable of the container
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# CMD instruction canbe used to provide the default arguments to an ENTRYPOINT
CMD ["mysqld", "--user=mysql"]

# mysqld:
# The MariaDB server daemon
# This is the actual database server process
# Listens on port 3306
# Handles all SQL queries

# --user=mysql:
# Run the server process as the mysql user (not root)
# Security best practice
# Even if compromised, attacker only has mysql user privileges
# Matches file ownership (all DB files owned by mysql:mysql)