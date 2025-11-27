FROM alpine:3.19

RUN apk update && apk add --no-cache mariadb mariadb-client

# Create the run directory for mysqld
RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Configure MariaDB to listen on all interfaces
RUN sed -i "s|skip-networking|# skip-networking|g" /etc/my.cnf.d/mariadb-server.cnf && \
    sed -i "s|.*bind-address\s*=.*|bind-address = 0.0.0.0|g" /etc/my.cnf.d/mariadb-server.cnf

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mysqld", "--user=mysql"]
