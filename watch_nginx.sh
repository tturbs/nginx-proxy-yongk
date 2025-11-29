#!/bin/sh

set -e

# Check if inotifywait is installed
if ! command -v inotifywait > /dev/null; then
    echo "inotifywait not found. Please install inotify-tools."
    echo "e.g., sudo apt-get update && sudo apt-get install inotify-tools"
    exit 1
fi

NGINX_CONFIG_PATH="./nginx.conf"

# Ensure the file exists before starting
if [ ! -f "$NGINX_CONFIG_PATH" ]; then
    echo "Error: $NGINX_CONFIG_PATH not found."
    exit 1
fi

echo "Watching $NGINX_CONFIG_PATH for changes..."

# Loop indefinitely
while true; do
    # Wait for any change to the file
    inotifywait -e modify -e close_write -e move_self -e delete_self "$NGINX_CONFIG_PATH"

    # If the file was deleted or moved, we should exit or handle it
    if [ ! -f "$NGINX_CONFIG_PATH" ]; then
        echo "Error: $NGINX_CONFIG_PATH was moved or deleted. Exiting."
        exit 1
    fi

    echo "Change detected in $NGINX_CONFIG_PATH. Reloading nginx..."

    # Test nginx configuration first
    if docker-compose exec nginx nginx -t; then
        # If config is ok, reload nginx
        docker-compose exec nginx nginx -s reload
        echo "Nginx reloaded successfully."
    else
        echo "Error: Nginx configuration test failed. Not reloading."
    fi
done
