FROM certbot/certbot
RUN pip install certbot-dns-duckdns
USER root
RUN mkdir -p /etc/letsencrypt && \
    mkdir -p /var/log/letsencrypt && \
    chown -R root:root /etc/letsencrypt && \
    chown -R root:root /var/log/letsencrypt
