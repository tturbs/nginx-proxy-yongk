#!/bin/sh

set -ex

echo "Starting certbot run.sh script..."

# DuckDNS credentials file
CREDENTIALS_FILE="/etc/letsencrypt/.secrets/duckdns.ini"
echo "CREDENTIALS_FILE: ${CREDENTIALS_FILE}"

# Domains (space-separated)
DOMAINS="basketball-scoreboard.duckdns.org commuzz.duckdns.org"
echo "DOMAINS: ${DOMAINS}"

# Build the -d arguments for certbot
CERT_DOMAINS=""
for DOMAIN in $DOMAINS; do
  CERT_DOMAINS="$CERT_DOMAINS -d $DOMAIN"
done
echo "CERT_DOMAINS: ${CERT_DOMAINS}"

echo "Attempting to issue certificates..."
# Issue certificates
certbot certonly \
  --authenticator dns-duckdns \
  --dns-duckdns-credentials "${CREDENTIALS_FILE}" \
  --email yonguk.ids@gmail.com \
  --agree-tos \
  --dns-duckdns-propagation-seconds 60 \
  $CERT_DOMAINS

echo "Certificate issuance attempt finished."
ls -lR /etc/letsencrypt/

echo "Script finished. Sleeping for 300 seconds for inspection."
sleep 300
