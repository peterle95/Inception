NAME = inception

all: build up

build:
	mkdir -p /home/pmolzer/data/mariadb
	mkdir -p /home/pmolzer/data/wordpress
	docker compose -f srcs/docker-compose.yml build

up:
	mkdir -p /home/pmolzer/data/mariadb
	mkdir -p /home/pmolzer/data/wordpress
	docker compose -f srcs/docker-compose.yml up -d

down:
	docker compose -f srcs/docker-compose.yml down

clean: down
	docker system prune -af

fclean: clean
	docker run --rm -v /home/pmolzer/data:/data alpine rm -rf /data/mariadb /data/wordpress
	docker volume rm srcs_mariadb srcs_wordpress || true

re: fclean all

.PHONY: all build up down clean fclean re