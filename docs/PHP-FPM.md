**PHP-FPM** (FastCGI Process Manager) is a specific implementation of PHP designed for high-traffic websites, providing superior performance, separate process isolation, and better resource management compared to running PHP as an Apache module (`mod_php`).

In the context of this Docker Compose project, PHP-FPM is a mandatory component of the **WordPress container**, serving as the application server that processes the PHP code for the website.

Here is everything you need to know about PHP-FPM and its implementation in this project infrastructure:

### 1. Role and Architecture

The project architecture relies on PHP-FPM to decouple the web serving (handled by NGINX) from the application processing (handled by PHP).

*   **WordPress Container Requirement:** The mandatory requirements strictly mandate a dedicated Docker container that contains **WordPress with php-fpm only**, specifically forbidding the presence of NGINX within that container.
*   **NGINX as Reverse Proxy:** NGINX handles the client connection (over TLS/HTTPS on port 443) and serves as a **reverse proxy**. When NGINX receives a request for a PHP file, it forwards that request to the separate PHP-FPM process running inside the WordPress container.
*   **Communication:** PHP-FPM does not handle HTTP requests directly. Communication between NGINX and PHP-FPM is handled internally within the Docker network using the **FastCGI protocol** on port **9000**.

### 2. Implementation in the WordPress Dockerfile

The WordPress container requires a custom Dockerfile to install and configure PHP-FPM and WordPress files.

| Element | Implementation Detail | Source |
| :--- | :--- | :--- |
| **Base Image** | Containers must be built from the penultimate stable version of Alpine or Debian, such as `alpine:3.19` or `debian:bookworm`. | |
| **Installation** | The Dockerfile must install `php-fpm` (e.g., `php81-fpm` or `php8.2-fpm`) using a package manager like `apk` or `apt`. | |
| **PHP Extensions** | Several PHP extensions are installed to ensure WordPress functionality, including `php-mysql` (or `php81-mysqli` / `php8.2-mysql`), along with extensions for handling archives, internationalization, and secure communication (`php81-openssl`, `php81-mbstring`, etc.). | |
| **Exposed Port** | The Dockerfile exposes port **9000** (`EXPOSE 9000`), documenting that this is the port PHP-FPM will listen on for incoming FastCGI connections from NGINX. | |
| **Entrypoint** | The `ENTRYPOINT` is typically set to a script (e.g., `/usr/local/bin/entrypoint.sh`) that manages database waiting, WordPress configuration (using `wp-cli`), and finally executes PHP-FPM. | |
| **Execution Command** | The container must run PHP-FPM in the **foreground** to prevent the container from exiting immediately, usually accomplished using `CMD ["php-fpm81", "-F"]` or similar options within the entrypoint script, which ensures it runs as PID 1. | |

### 3. PHP-FPM Configuration (`www.conf`)

A configuration file, typically `conf/www.conf`, is copied into the container to define the FastCGI parameters:

*   **Listener:** It configures PHP-FPM to `listen = 9000`, enabling it to accept connections from NGINX on that port.
*   **User/Group:** It sets the user and group for the worker processes (e.g., `user = www-data` or `user = nobody`).
*   **Process Management (`pm`):** It sets the process manager mode to `dynamic` and specifies parameters controlling the number of worker processes, such as `pm.max_children`, `pm.start_servers`, and `pm.max_spare_servers`. These settings are critical for better resource management.

### 4. NGINX Configuration and Connection

NGINX handles the routing of PHP execution requests using the **FastCGI protocol**:

*   The NGINX configuration file includes a `location ~ \.php$` block to handle PHP file requests.
*   Inside this block, the `fastcgi_pass` directive directs the request to the WordPress service container and the FastCGI port: `fastcgi_pass wordpress:9000`.
*   The `wordpress` name is resolved internally because both NGINX and WordPress containers share the same user-defined **Docker bridge network** (e.g., `inception-network`).

To visualize the workflow, think of the arrangement like a multi-stage production line:
1.  **NGINX (The Clerk):** Takes the public request (HTTPS/443).
2.  **NGINX (The Manager):** Sees the request needs application logic (a `.php` file) and sends the request internally to the application handler using the dedicated FastCGI door (Port 9000).
3.  **PHP-FPM (The Chef):** Receives the request on port 9000, processes the WordPress logic (often talking to MariaDB), and generates the final HTML output.
4.  **NGINX (The Clerk):** Takes the generated output from PHP-FPM and delivers it back to the client over the secure HTTPS connection.