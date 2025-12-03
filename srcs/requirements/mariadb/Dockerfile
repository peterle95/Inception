FROM alpine:3.19

RUN apk update && apk add --no-cache mariadb mariadb-client

# Create the run directory for mysqld
RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy custom MariaDB configuration
COPY conf/50-server.cnf /etc/my.cnf.d/50-server.cnf

# EXPOSE is the port that the container will listen on
# it doesn't open the port, it just tells Docker that the container will listen on that port
# and that the port should be mapped to the host
EXPOSE 3306

# ENTRYPOINT is the script that will be executed when the container starts
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# CMD is the command that will be executed when the container starts
CMD ["mysqld", "--user=mysql"] 