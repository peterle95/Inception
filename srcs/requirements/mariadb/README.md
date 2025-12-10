# MariaDB Container Documentation

## 1. Container Overview

### Purpose and Role
The MariaDB container provides the persistent relational database storage for the Inception infrastructure. It stores all WordPress content, including posts, pages, comments, and user configurations.

The "relational" in relational database means that the database stores data in tables with predefined relationships between them. 

A relational model organizes data into one or more tables (or "relations") of columns and rows, with a unique key identifying each row. 

### Key Responsibilities
- **Data Storage**: Persistently stores application data.
- **Data Integrity**: Ensures ACID compliance for transactions.
- **Security**: Manages user authentication and privileges for database access.

### Relationship to Other Services
- **WordPress**: Acts as the backend for the WordPress container. The WordPress container connects to this service on port 3306.
- **Volumes**: Uses a dedicated mariadb volume to persist database files across container restarts.

## 2. Technical Specifications

### Software Packages
- **OS Base**: Debian Bookworm (Stable)
- **Database Server**: MariaDB Server (Latest stable from Debian repositories)
- **Database Client**: MariaDB Client (for initialization and health checks)

### Dependencies
- **Secrets**: Requires db_root_password and db_password secrets to be mounted in /run/secrets/.
- **Volume**: Requires a persistent volume mounted at /var/lib/mysql.

## 3. Configuration

### Configuration Files
- **Main Config**: /etc/mysql/mariadb.conf.d/50-server.cnf
  - **Bind Address**: 0.0.0.0 (Allows connections from other containers, specifically WordPress).
  - **Port**: 3306.
  - **Character Set**: utf8mb4 (Full Unicode support).

### Environment Variables & Secrets
- **Secrets**:
  - db_root_password: Root password for the database.
  - db_password: Password for the WordPress database user.
- **Environment Variables**:
  - MYSQL_DATABASE: Name of the database to create (e.g., inception).
  - MYSQL_USER: Name of the user to create.
  - MYSQL_ROOT_PASSWORD / MYSQL_PASSWORD: Populated from secrets by the entrypoint script.

### Security Considerations
- **Network Isolation**: Only reachable within the inception docker network.
- **Secrets Management**: Passwords are not hardcoded but injected via Docker Secrets.
- **Root Restriction**: Root access is configured but the application uses a restricted user.

## 4. Dockerfile Analysis

`dockerfile
FROM debian:bookworm

# Install MariaDB
RUN apt-get update && apt-get install -y \
    mariadb-server \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Setup Directories
RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld
RUN mkdir -p /var/lib/mysql && chown -R mysql:mysql /var/lib/mysql

# Copy Scripts and Config
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Expose Port
EXPOSE 3306

# Start
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mysqld", "--user=mysql"]
`

- **Installation**: Installs MariaDB server and client tools.
- **Directory Setup**: Ensures critical runtime directories (/run/mysqld) exist with correct permissions (mysql:mysql), which is often a source of startup failures.
- **Configuration**: Injects the custom 50-server.cnf to override default binding behavior.
- **Entrypoint**: Uses a custom script to handle first-run initialization securely.

## 5. Operational Details

### Expected Runtime Behavior
1. **Initialization**: On first run (if /var/lib/mysql/mysql is missing), the entrypoint initializes the database data directory.
2. **User Setup**: A temporary MariaDB daemon is started to create the specified database and users using SQL commands.
3. **Serving**: The temporary daemon is stopped, and the main mysqld process starts, listening for connections.

### Logging
- **General Logs**: Output to stdout/stderr, accessible via docker logs.
- **Initialization Logs**: The entrypoint script prints steps ("Initializing database...", "Setting up database and user...") to indicate progress.

### Common Troubleshooting
- **Permission Errors**: If the volume mount permissions are incorrect, MariaDB will fail to start. The Dockerfile attempts to fix this with chown.
- **Connection Refused**: Usually means MariaDB is not bound to 0.0.0.0 or the initialization phase failed.

## 6. Architectural Context

### Diagram
`mermaid
graph LR
    WP[WordPress Container] -- TCP:3306 --> DB[MariaDB Container]
    DB -- Reads/Writes --> Volume[MariaDB Volume]
`

### Communication
- **Internal**: Listens on TCP port 3306.
- **Protocol**: MySQL Client/Server protocol.

### Performance & Scaling
- **Volume Performance**: Database performance is heavily dependent on the I/O performance of the underlying volume mount (/home/pmolzer/data/mariadb).
- **Memory**: Configured to use defaults, but can be tuned in 50-server.cnf for higher loads (e.g., buffer pool size).
