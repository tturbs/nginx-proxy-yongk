#!/bin/sh

set -ex

echo "Starting certbot run.sh script..."

# DuckDNS credentials file
CREDENTIALS_FILE="/etc/letsencrypt/.secrets/duckdns.ini"
echo "CREDENTIALS_FILE: ${CREDENTIALS_FILE}"

# Domains (space-separated)
DOMAINS="basketball-scoreboard.duckdns.org commuzz.duckdns.org"
echo "DOMAINS: ${DOMAINS}"

# First, try to renew any existing certificates
certbot renew --non-interactive

# Then, issue certificates for any domains that don't have one
for DOMAIN in $DOMAINS; do
  if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "Attempting to issue certificate for $DOMAIN..."
    certbot certonly \
      --authenticator dns-duckdns \
      --dns-duckdns-credentials "${CREDENTIALS_FILE}" \
      --email yonguk.ids@gmail.com \
      --agree-tos \
      --dns-duckdns-propagation-seconds 60 \
      --non-interactive \
      -d "$DOMAIN"
    echo "Certificate issuance attempt for $DOMAIN finished."
  else
    echo "Certificate for $DOMAIN already exists."
  fi
done

ls -lR /etc/letsencrypt/

echo "Script finished."
