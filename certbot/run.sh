#!/bin/sh

set -e

# DuckDNS credentials file
CREDENTIALS_FILE="/etc/letsencrypt/.secrets/duckdns.ini"

# Domains
DOMAINS=(
  "basketball-scoreboard.duckdns.org"
  "commuzz.duckdns.org"
)

# Join domains for certbot command
CERT_DOMAINS=""
for DOMAIN in "${DOMAINS[@]}"; do
  CERT_DOMAINS="${CERT_DOMAINS}-d ${DOMAIN} "
done

# Issue or renew certificate
certbot certonly \
  --dns-duckdns \
  --dns-duckdns-credentials "${CREDENTIALS_FILE}" \
  --email yonguk.ids@gmail.com \
  --agree-tos \
  --no-eff-email \
  --expand \
  ${CERT_DOMAINS}

# Renewal loop
while true; do
    echo "Renewing certificates..."
    certbot renew --quiet
    sleep 12h
done
