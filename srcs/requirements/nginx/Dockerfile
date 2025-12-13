FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

COPY conf/nginx.conf /etc/nginx/sites-available/default
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

# nginx:
# The NGINX web server executable
# Handles HTTPS connections on port 443
# Serves static files
# Proxies PHP requests to WordPress container

# -g flag:
# Set global directive
# Allows passing configuration directives via command line
# Overrides settings in nginx.conf
# Syntax: -g "directive value;"

# daemon off;:
# NGINX configuration directive
# Prevents NGINX from daemonizing (going to background)
# Forces foreground mode
# Same reason as php-fpm's -F flag