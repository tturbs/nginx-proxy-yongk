#!/bin/sh

set -e

CREDENTIALS_FILE="/etc/letsencrypt/.secrets/duckdns.ini"

# Initial certificate issuance is handled by the first run of this script.
# This loop is for automatic renewal.

while true; do
    echo "Renewing certificates..."
    certbot renew --quiet
    sleep 12h
done
