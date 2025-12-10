# NGINX Container Documentation

## 1. Container Overview

### Purpose and Role
The NGINX container serves as the primary entry point and web server for the Inception infrastructure. It acts as a reverse proxy and secure web server, handling all incoming HTTP/HTTPS traffic and routing PHP requests to the WordPress application container.

### Key Responsibilities
- **TLS/SSL Termination**: Handles secure connections using TLS v1.3.
- **Static Content Serving**: Directly serves static files (HTML, CSS, JS, images).
- **Reverse Proxy**: Forwards PHP requests to the WordPress container via the FastCGI protocol.
- **Security**: Implements access controls and secure communication protocols.

### Relationship to Other Services
- **WordPress**: Depends on the WordPress container for dynamic content generation. Connects to wordpress:9000.
- **Volumes**: Mounts the shared wordpress volume to access the website's static files and code.

## 2. Technical Specifications

### Software Packages
- **OS Base**: Debian Bookworm (Stable)
- **Web Server**: NGINX (Latest stable from Debian repositories)
- **Utilities**: 
  - openssl: For generating self-signed certificates.
  - curl & ca-certificates: For network diagnostics and secure connections.

### Dependencies
- **System**: Requires a host capable of running Docker/OCI containers.
- **Network**: Must be attached to the inception bridge network.
- **Volume**: Requires read access to the WordPress application volume.

## 3. Configuration

### Configuration Files
- **Main Config**: /etc/nginx/sites-available/default (copied from conf/nginx.conf)
  - Configures the server block for pmolzer.42.fr.
  - Sets up SSL listening on port 443.
  - Defines root directory as /var/www/html.
  - Configures FastCGI pass to wordpress:9000.

### Environment Variables
This container typically consumes environment variables defined in the .env file at the project root, primarily for network and domain configuration, though the specific 
ginx.conf provided hardcodes the domain pmolzer.42.fr.

### Security Considerations
- **TLS 1.3**: Only the latest, most secure TLS protocol is enabled.
- **Port 443 Only**: Only secure HTTPS traffic is accepted; HTTP is not exposed.
- **Self-Signed Certificates**: Generated automatically on startup if missing, ensuring encryption is always active.
- **Hidden Files**: Access to dotfiles (e.g., .env, .git) is explicitly denied.

## 4. Dockerfile Analysis

`dockerfile
FROM debian:bookworm

# Install NGINX and OpenSSL
RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copy Configuration
COPY conf/nginx.conf /etc/nginx/sites-available/default

# Copy and setup entrypoint
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose HTTPS port
EXPOSE 443

# Start command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
`

- **Base Image**: Uses debian:bookworm for stability and security updates.
- **Package Installation**: Installs necessary packages and cleans up apt lists to reduce image size.
- **Configuration**: Overwrites the default NGINX site configuration with our custom secure config.
- **Entrypoint**: Sets a custom entrypoint script to handle runtime setup (certificates) before starting the server.

## 5. Operational Details

### Expected Runtime Behavior
1. **Startup**: The entrypoint.sh script runs.
2. **Certificate Check**: Checks for SSL certificates in /etc/nginx/ssl. If missing, generates a self-signed certificate for pmolzer.42.fr.
3. **Dependency Check**: Waits for the wordpress host to be resolvable.
4. **Service Start**: Starts NGINX in the foreground (daemon off).

### Logging
- **Access Logs**: Standard NGINX access logs (stdout).
- **Error Logs**: Standard NGINX error logs (stderr).
- **Startup Logs**: The entrypoint script logs certificate generation status and connection attempts to WordPress.

### Common Troubleshooting
- **502 Bad Gateway**: Usually indicates the WordPress container is down or not reachable on port 9000.
- **Certificate Errors**: Browsers will warn about the self-signed certificate; this is expected behavior for this development setup.

## 6. Architectural Context

### Diagram
`mermaid
graph LR
    User[User Browser] -- HTTPS:443 --> Nginx[NGINX Container]
    Nginx -- Static Files --> Volume[WordPress Volume]
    Nginx -- FastCGI:9000 --> WP[WordPress Container]
`

### Communication
- **External**: Accepts connections on port 443 (mapped to host 443).
- **Internal**: Communicates with wordpress container via TCP on port 9000 using the FastCGI protocol.

### Performance & Scaling
- NGINX is highly efficient at serving static files directly.
- Offloading PHP processing to a separate container allows independent scaling of web serving and application processing resources.
