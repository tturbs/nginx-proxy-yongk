# Nginx Proxy

An independent reverse proxy server configuration using Nginx and Certbot to manage multiple domains with automated SSL certificate issuance and renewal via Let's Encrypt.

## Overview

This project provides a centralized Nginx reverse proxy, decoupled from backend applications. It's designed to sit in front of other Dockerized applications (like `basketball-scoreboard`, `commuzz`, etc.) and route traffic to them based on domain name.

SSL certificates are automatically handled by a dedicated `certbot` service, using the DNS-01 challenge with the DuckDNS provider.

## Directory Structure

```
nginx-proxy-yongk/
├── docker-compose.yml      # Defines the nginx and certbot services.
├── nginx.conf              # Main Nginx configuration for all domains.
├── certbot/
│   ├── Dockerfile          # Dockerfile for the certbot service.
│   ├── run.sh              # Script to issue and renew certificates.
│   └── conf/               # Stores certbot certificates and account info.
│       └── .secrets/
│           └── duckdns.ini # DuckDNS API token (MUST be created manually).
├── watch_nginx.sh          # (Optional) Script to auto-reload Nginx on config changes.
└── README.md               # This file.
```

## Initial Setup

1.  **Clone the Repository:**
    ```bash
    git clone <repository_url>
    cd nginx-proxy-yongk
    ```

2.  **Create Shared Docker Network:**
    This proxy and the backend applications communicate over a shared Docker network.
    ```bash
    docker network create shared-network
    ```

3.  **Configure DuckDNS Token:**
    The `certbot` service needs your DuckDNS API token to perform DNS challenges.
    
    a. Create the secrets directory:
    ```bash
    mkdir -p certbot/conf/.secrets
    ```

    b. Create and edit the `duckdns.ini` file:
    ```bash
    nano certbot/conf/.secrets/duckdns.ini
    ```

    c. Add your token in the following format and save the file:
    ```ini
    # DuckDNS API token
    dns_duckdns_token = YOUR_DUCKDNS_TOKEN_HERE
    ```

4.  **Start the Services:**
    ```bash
    docker-compose up -d --build
    ```

## Usage

### Starting and Stopping Services

-   **Start:** `docker-compose up -d`
-   **Stop:** `docker-compose down`

### Automatic Nginx Reloading

The `watch_nginx.sh` script monitors `nginx.conf` for any changes and automatically reloads Nginx gracefully. This avoids the need to manually restart the service after a configuration update.

**Prerequisites:**
You must have `inotify-tools` installed.
```bash
# For Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y inotify-tools
```

**To use the script:**
Make sure it is executable (`chmod +x watch_nginx.sh`) and run it in the background:
```bash
./watch_nginx.sh &
```
It will now watch for changes and reload Nginx automatically.

## Managing Domains

### How to Add a New Domain (e.g., `new-app.duckdns.org`)

Here is the step-by-step guide to add a new domain to the proxy.

**1. Create an External Volume for the Frontend (if needed):**
If your new service serves static files, create a Docker volume for them.
```bash
docker volume create new-app_frontend-build
```

**2. Update `docker-compose.yml`:**

a. **Add a volume mount** for the new application's frontend files under the `nginx` service:
```yaml
services:
  nginx:
    # ...
    volumes:
      # ... other volumes
      - new-app-frontend:/usr/share/nginx/new-app:ro
```

b. **Define the external volume** at the bottom of the file:
```yaml
volumes:
  # ... other volumes
  new-app-frontend:
    external: true
    name: new-app_frontend-build
```

**3. Update `certbot/run.sh`:**

Add your new domain to the `certbot certonly` command. It's crucial to add it to the end of the `-d` list and keep the `--expand` flag.

```bash
# ...
certbot certonly \
    # ... other flags
    -d basketball-scoreboard.duckdns.org \
    -d commuzz.duckdns.org \
    -d new-app.duckdns.org \ # <-- Add new domain here
    --expand \
    # ...
```

**4. Update `nginx.conf`:**

Add a new `upstream` and `server` block for your new domain. You can copy an existing block and modify it.

```nginx
# Upstream for the new app's backend API
upstream new-app-backend {
    server new-app-backend:8000; # Use the correct container name and port
}

# ...

# Server block for the new domain
server {
    listen 80;
    server_name new-app.duckdns.org;
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name new-app.duckdns.org;

    # Use the existing, expanded certificate
    ssl_certificate /etc/letsencrypt/live/basketball-scoreboard.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/basketball-scoreboard.duckdns.org/privkey.pem;

    # ... (copy other SSL settings)

    # Proxy API requests
    location /api/ {
        proxy_pass http://new-app-backend;
        # ... (copy other proxy settings)
    }

    # Serve frontend files
    location / {
        root /usr/share/nginx/new-app;
        try_files $uri $uri/ /index.html;
    }
}
```

**5. Re-run Certbot and Restart Services:**

Because you have modified the `run.sh` script to include a new domain, you need to stop, remove, and rebuild the `certbot` container to force it to run the issuance command again.

```bash
# Stop and remove the old certbot container
docker-compose stop certbot
docker-compose rm -f certbot

# Rebuild and start all services. This will run the updated script.
docker-compose up -d --build
```
After this, the new certificate will be issued, and Nginx will serve the new domain.

**6. Finalize `run.sh`:**
After confirming the new certificate is active, it's good practice to edit `run.sh` again and replace the `certonly` command with the simpler `renew` command inside the loop, to avoid re-issuing certificates on every container start.
```bash
# Final run.sh content
#!/bin/sh
set -e
while true; do
    certbot renew --quiet
    sleep 12h
done
```
Then run `docker-compose up -d` to apply the final script.

```