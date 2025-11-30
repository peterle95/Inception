FROM alpine:3.19

RUN apk update && apk add --no-cache nginx openssl

COPY conf/nginx.conf /etc/nginx/http.d/default.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]