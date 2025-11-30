#!/bin/sh

set -e

# DuckDNS credentials file
CREDENTIALS_FILE="/etc/letsencrypt/.secrets/duckdns.ini"

# Domains (space-separated)
DOMAINS="basketball-scoreboard.duckdns.org commuzz.duckdns.org"

# Issue or renew certificate
certbot certonly \
  --dns-duckdns \
  --dns-duckdns-credentials "${CREDENTIALS_FILE}" \
  --email yonguk.ids@gmail.com \
  --agree-tos \
  --no-eff-email \
  --expand \
  -d $(echo $DOMAINS | sed 's/ / -d /g')

# Renewal loop
while true; do
    echo "Renewing certificates..."
    certbot renew --quiet
    sleep 12h
done
