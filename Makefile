NAME = inception

all: build up

build: # build containers
	@echo "Building containers..."
	mkdir -p /home/pmolzer/data/mariadb
	mkdir -p /home/pmolzer/data/wordpress
	docker compose -f srcs/docker-compose.yml build

rebuild: # complete rebuild from scratch
	@echo "Rebuilding from scratch..."
	docker compose -f srcs/docker-compose.yml build --no-cache

up: # start containers
	@echo "Starting containers..."
	docker compose -f srcs/docker-compose.yml up -d

down: # stop containers
	@echo "Stopping containers..."
	docker compose -f srcs/docker-compose.yml down

clean: down # clean system
	@echo "Cleaning system..."
	docker system prune -af

fclean: clean # fully clean system
	@echo "Fully cleaning system..."
	docker run --rm -v /home/pmolzer/data:/data debian:bookworm-slim rm -rf /data/mariadb /data/wordpress
	docker volume rm srcs_mariadb srcs_wordpress || true

re: fclean all # rebuild from scratch
	@echo "Rebuilding from scratch..."
	docker compose -f srcs/docker-compose.yml build --no-cache
	@echo "Starting containers..."
	docker compose -f srcs/docker-compose.yml up -d

.PHONY: all build up down clean fclean re