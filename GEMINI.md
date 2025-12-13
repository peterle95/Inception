# Project Overview

This project sets up a complete WordPress installation using Docker. It consists of three main services orchestrated by Docker Compose:

*   **Nginx:** Acts as the web server and reverse proxy, handling HTTPS traffic. It's configured to serve the WordPress files and is the only service exposed to the host machine (on port 443).
*   **MariaDB:** A relational database server that stores all of WordPress's data. It is not directly accessible from the host machine.
*   **WordPress:** The core application, which runs on PHP-FPM. It communicates with the Nginx server to handle web requests and with the MariaDB server to store and retrieve data.

The entire setup is designed to be self-contained and easily managed through a `Makefile`.

## Building and Running

The project is managed via a `Makefile` which simplifies the Docker Compose commands.

*   **Build the containers:**
    ```bash
    make build
    ```

*   **Start the containers in detached mode:**
    ```bash
    make up
    ```

*   **Stop the containers:**
    ```bash
    make down
    ```

*   **Clean the system (removes stopped containers and networks):**
    ```bash
    make clean
    ```

*   **Full clean (removes all data and volumes):**
    ```bash
    make fclean
    ```

*   **Rebuild from scratch:**
    ```bash
    make re
    ```

## Development Conventions

*   **Docker-centric:** All development and deployment is done through Docker containers.
*   **Secrets Management:** Sensitive information like database passwords and WordPress admin credentials are not stored in the repository. Instead, they are managed through Docker Secrets, with the secret files located in the `secrets/` directory.
*   **Environment Variables:** Non-sensitive configuration is managed through the `srcs/.env` file.
*   **Entrypoint Scripts:** Each service has its own `entrypoint.sh` script in the `tools/` directory of its respective `requirements` subdirectory. These scripts handle service initialization, such as creating self-signed SSL certificates (Nginx), initializing the database (MariaDB), and installing WordPress (WordPress).
