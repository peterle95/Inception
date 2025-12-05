The term **PID** in the context of the project refers primarily to **Process ID 1 (PID 1)**, which holds a special and critical role within Unix systems, including Docker containers.

Here is a breakdown of what PID 1 is and where you must implement best practices related to it in your project:

### What is PID 1?

In Unix systems, **PID 1 is the init process**. This process is vital for the stability and proper function of the environment because it is responsible for three main tasks:

1.  Managing child processes.
2.  Handling system signals (like shutdown commands).
3.  Cleaning up "zombie" processes.

In a Docker container, the primary program that starts when the container launches takes on PID 1. It is considered a **best practice** that the main application or service (the daemon) runs as PID 1 in the foreground.

If the main process is run indirectly by a shell (like `bash` or `sh`) that then launches the daemon in the background, the shell takes PID 1, and the main application (e.g., NGINX) might not receive termination signals correctly, leading to messy shutdowns or zombie processes. This is why the project rules strictly prohibit running commands in the background using methods like `tail -f`, `sleep infinity`, or `nginx & bash`.

### Where to Implement PID 1 Best Practices

You are explicitly required to "Read about **PID 1** and the best practices for writing Dockerfiles". This implementation affects the configuration of all mandatory services (NGINX, WordPress/PHP-FPM, and MariaDB) to ensure they run correctly as PID 1 in the foreground:

1.  **In Dockerfiles and Entrypoint Scripts (Mandatory for all services):** You must ensure that the main process of the service is executed directly (often using the `exec` command within a shell script or the JSON array format for `CMD` or `ENTRYPOINT`) to occupy PID 1 and run in the foreground.
2.  **NGINX Container:** You implement this by using a command that runs the web server in the foreground, typically using `-g "daemon off;"`. For example, the `CMD` instruction is defined as `CMD ["nginx", "-g", "daemon off;"]` to ensure NGINX runs as the primary process.
3.  **WordPress/PHP-FPM Container:** PHP-FPM must be run in the foreground using the `-F` flag, ensuring it remains the primary process, such as in the command `exec php-fpm8.2 -F` or `CMD ["php-fpm81", "-F"]`. The entrypoint script is typically used to perform setup tasks and then executes the PHP-FPM foreground command using `exec "$@"` to hand off PID 1.
4.  **MariaDB Container:** While MariaDB configuration files may include a `pid-file = /var/run/mysqld/mysqld.pid` setting, the key implementation is ensuring the final MariaDB server command in the entrypoint script is run using `exec mysqld --user=mysql` or similar, to become PID 1.

By adhering to these practices, you avoid "hacky patches" and commands that run infinite loops, which are explicitly forbidden.

---
*Analogy:* Think of PID 1 in a Docker container as the captain of a small submarine. If you launch the captain (your main application, like NGINX) directly, they manage the entire operation and can properly receive the "shut down" signals. If you launch a junior officer (a bash script) who then tells the captain to stand watch in the background, the junior officer becomes the "captain" (PID 1), but they don't know how to handle the signals or clean up messes, leading to operational instability.