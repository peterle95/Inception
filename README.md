# Inception

This project sets up a small infrastructure using Docker Compose with three services: NGINX, MariaDB, and WordPress.

## Architecture

- **NGINX**: Reverse proxy with TLS v1.2/v1.3 (entry point on port 443)
- **MariaDB**: Database server for WordPress
- **WordPress**: CMS with PHP-FPM (no built-in web server)
- **Network**: Custom Docker bridge network (`inception`)
- **Volumes**: Persistent storage for database and WordPress files

## Prerequisites

- Docker and Docker Compose installed
- Root/sudo access (for editing `/etc/hosts`)

## Step-by-Step Setup

### Step 1: Configure Domain Name

Add the domain to your hosts file:

```bash
sudo nano /etc/hosts
```

Add this line (keep your existing entries):
```
127.0.0.1 localhost
127.0.1.1 debian.pmolzer debian
127.0.0.1 peter.42.fr
```

Save and exit (Ctrl+X, Y, Enter).

**Verify**: Test DNS resolution:
```bash
ping peter.42.fr
```
You should see responses from `127.0.0.1`.

### Step 2: Build the Infrastructure

Build all Docker images:

```bash
make build
```

**What you should see**:
- Building nginx... (Alpine 3.19 base, installing nginx and openssl)
- Building mariadb... (Alpine 3.19 base, installing mariadb)
- Building wordpress... (Alpine 3.19 base, installing PHP 8.1, WP-CLI)
- All builds complete successfully

This takes 1-3 minutes depending on your internet connection.

### Step 3: Start the Services

Start all containers:

```bash
make up
```

**What you should see**:
- Creating network `srcs_inception`
- Creating volumes `srcs_mariadb` and `srcs_wordpress`
- Starting containers: `mariadb`, `nginx`, `wordpress`
- All containers show "Started"

### Step 4: Verify Containers Are Running

Check container status:

```bash
docker ps
```

**Expected output**:
```
CONTAINER ID   IMAGE       COMMAND                  STATUS          PORTS
xxxxxxxxxx     nginx       "/usr/local/bin/entr…"   Up X seconds    0.0.0.0:443->443/tcp
xxxxxxxxxx     mariadb     "/usr/local/bin/entr…"   Up X seconds    3306/tcp
xxxxxxxxxx     wordpress   "/usr/local/bin/entr…"   Up X seconds    9000/tcp
```

All three containers should be "Up".

### Step 5: Check WordPress Installation

Monitor WordPress initialization:

```bash
docker logs wordpress
```

**What you should see**:
```
Waiting for MariaDB...
Downloading WordPress...
Success: WordPress downloaded.
Configuring WordPress...
Success: Generated 'wp-config.php' file.
Installing WordPress...
Success: WordPress installed successfully.
Creating user...
Success: Created user 2.
Starting PHP-FPM...
```

Wait until you see "Starting PHP-FPM..." (takes ~30 seconds).

### Step 6: Access WordPress

Open your browser and navigate to:
```
https://peter.42.fr
```

**What you should see**:
1. **Security Warning**: Your browser will warn about the self-signed certificate. This is expected.
   - Click "Advanced" → "Accept the Risk and Continue" (Firefox)
   - Or "Advanced" → "Proceed to peter.42.fr" (Chrome)

2. **WordPress Homepage**: You should see the default WordPress site with the "Inception" title.

### Step 7: Login to WordPress Admin

Navigate to the admin panel:
```
https://peter.42.fr/wp-admin
```

**Login credentials** (from `.env` file):
- **Admin Username**: `peter`
- **Admin Password**: `adminsecret123`

**What you should see**:
- WordPress admin dashboard
- Two users in the system:
  - `peter` (Administrator)
  - `normaluser` (Author)

### Step 8: Verify Data Persistence

Test that data persists across restarts:

```bash
# Stop containers
make down

# Start again
make up

# Check the site - your data should still be there
```

Visit `https://peter.42.fr` - the site should load with all previous data intact.

## Available Commands

| Command | Description |
|---------|-------------|
| `make` | Build and start everything (equivalent to `make all`) |
| `make build` | Build all Docker images |
| `make up` | Start all containers in detached mode |
| `make down` | Stop and remove all containers |
| `make clean` | Stop containers and prune Docker system |
| `make fclean` | Full clean (removes containers, volumes, and data directories) |
| `make re` | Rebuild everything from scratch (`fclean` + `all`) |

## Troubleshooting

### Containers won't start
```bash
# Check logs for each service
docker logs nginx
docker logs mariadb
docker logs wordpress
```

### Port 443 already in use
```bash
# Find what's using port 443
sudo lsof -i :443

# Stop the conflicting service or change the port in docker-compose.yml
```

### WordPress shows "Error establishing database connection"
```bash
# Check MariaDB is running
docker logs mariadb

# Restart the stack
make down && make up
```

### Permission issues with volumes
```bash
# Clean everything and rebuild
make fclean
make all
```

## Project Structure

```
.
├── Makefile                          # Build automation
├── README.md                         # This file
├── secrets/                          # Docker secrets (gitignored)
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                          # Environment variables (gitignored)
    ├── docker-compose.yml            # Service orchestration
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── README.md
        │   └── tools/
        │       └── entrypoint.sh
        ├── nginx/
        │   ├── Dockerfile
        │   ├── README.md
        │   ├── conf/
        │   │   └── nginx.conf
        │   └── tools/
        │       └── entrypoint.sh
        └── wordpress/
            ├── Dockerfile
            ├── README.md
            └── tools/
                └── entrypoint.sh
```

## Security Notes

- All passwords are stored in `.env` and `secrets/` (should be gitignored)
- TLS uses a self-signed certificate (for production, use Let's Encrypt)
- Database is only accessible within the Docker network
- NGINX is the only service exposed to the host (port 443)

## Data Storage

Persistent data is stored in:
- `/home/peter/data/mariadb` - Database files
- `/home/peter/data/wordpress` - WordPress files

These directories are created automatically by the Makefile.
