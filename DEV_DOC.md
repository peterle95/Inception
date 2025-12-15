# Developer Documentation (DEV_DOC.md)

## Overview

This document is intended for developers who want to understand, build, run, and maintain the **Inception** project. It explains how to set up the environment from scratch, how the Docker-based infrastructure is organized, and how to manage containers, volumes, and persistent data during development.

The project uses **Docker** and **Docker Compose** to orchestrate a small web stack composed of multiple services running in isolated containers.

---

## Services Provided by the Stack

The stack consists of the following services:

* **Nginx** – Web server and reverse proxy (TLS enabled)
* **WordPress** – PHP-based CMS
* **MariaDB** – Relational database used by WordPress

All services communicate through a **Docker network** and do not rely on host-level services.

---

## Prerequisites

Before building or running the project, ensure the following tools are installed on your system:

* **Docker** (>= 20.x)
* **Docker Compose** (v2 recommended)
* **Make**
* **GNU/Linux environment** (project is designed for Linux)

You can verify installations with:

```bash
docker --version
docker compose version
make --version
```

---

## Repository Structure

Key directories and files:

```
.
├── Makefile
├── docker-compose.yml
├── secrets/
│   ├── db_root_password.txt
│   ├── db_password.txt
│   └── credentials.txt
├── srcs/
│   ├── requirements/
│   │   ├── nginx/
│   │   ├── wordpress/
│   │   └── mariadb/
│   └── .env (if applicable)
├── README.md
├── USER_DOC.md
└── DEV_DOC.md
```

---

## Secrets and Configuration

### Secrets

Sensitive information is stored using **Docker secrets**, not hard-coded values or plain environment variables.

Typical secrets include:

* MariaDB root password
* WordPress database user password
* WordPress admin credentials

They are located in the `secrets/` directory and referenced in `docker-compose.yml`:

```yaml
secrets:
  db_root_password:
    file: ./secrets/db_root_password.txt
```

Each secret file contains **only the secret value**, without quotes or extra whitespace.

### Environment Variables

Environment variables are used only for **non-sensitive configuration** (e.g. database name, user names). These are defined either in the `docker-compose.yml` file or an optional `.env` file.

---

## Building and Launching the Project

### Using the Makefile

The project is managed primarily through the **Makefile**.

Common targets:

```bash
make up       # Build images and start containers
make down     # Stop and remove containers
make re       # Rebuild everything from scratch
make clean    # Remove containers
make fclean   # Remove containers, images, volumes, and data
```

> ⚠️ `make fclean` will **delete all persistent data**.

### Manual Docker Compose Usage

Alternatively, you can use Docker Compose directly:

```bash
docker compose up --build
docker compose down
```

---

## Container Management

Useful Docker commands during development:

```bash
# List running containers
docker ps

# View logs of a service
docker logs mariadb
docker logs wordpress
docker logs nginx

# Execute a shell inside a container
docker exec -it wordpress bash

# Stop all services
docker compose stop

# Restart services
docker compose restart
```

---

## Networking

* All containers are connected via a **custom Docker network**
* Services communicate using **service names** as hostnames (e.g. `mariadb:3306`)
* No internal service ports are exposed to the host unless explicitly required

This improves security and mirrors production-like isolation.

---

## Volumes and Data Persistence

### Volumes Used

Persistent data is stored using **Docker volumes**:

* MariaDB data (`/var/lib/mysql`)
* WordPress files (`/var/www/html`)

These volumes ensure that data persists across container restarts.

### Data Location on Host

Depending on your setup, volumes may be:

* Named Docker volumes
* Or mapped to directories such as:

```
/home/<user>/data/mariadb
/home/<user>/data/wordpress
```

This design allows easy inspection, backup, and reset of data.

---

## Rebuilding and Resetting the Environment

If something goes wrong during development:

```bash
make fclean
make up
```

This will:

* Stop all containers
* Remove images and volumes
* Rebuild everything from scratch

Use this when debugging build issues or corrupted data.

---

## Development Notes

* Containers are built from **custom Dockerfiles**, not official images alone
* TLS is handled by **Nginx**
* WordPress is configured automatically during container startup
* MariaDB initialization scripts run only on first startup (volume-based)

---

## Troubleshooting

Common checks:

* Verify secrets files exist and are readable
* Ensure no services are running on required ports
* Check logs for startup errors
* Confirm volumes are correctly mounted

```bash
docker compose logs
```

---

## Conclusion

This document should give developers everything needed to understand, build, run, and maintain the Inception project. For user-facing usage and administration, refer to **USER_DOC.md**. For design choices and theoretical explanations, refer to **README.md**.
