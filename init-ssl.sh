#!/bin/bash
set -e

echo "========================================"
echo "  Tarmeez Hub - SSL Initialization"
echo "========================================"

# 1. Create necessary directories to avoid permission issues
echo "-> Creating directories..."
mkdir -p /opt/tarmeez/data/certbot/conf
mkdir -p /opt/tarmeez/data/certbot/www

# Backup production config temporarily
if [ -f "nginx/conf.d/default.conf" ]; then
    cp nginx/conf.d/default.conf nginx/conf.d/default.conf.bak
fi

# 2. Apply temporary configuration for Step A
echo "-> Creating temporary Nginx config for ACME challenges..."
cat << 'EOF' > nginx/conf.d/default.conf
server {
    listen 80;
    listen [::]:80;
    server_name tarmeez.cloud www.tarmeez.cloud;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOF

# 3. Start Nginx
echo "-> Starting Nginx with temporary config..."
docker-compose up -d nginx

# 4. Fetch the initial certificate (Step B)
echo "-> Fetching initial SSL certificate..."
docker-compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot -d tarmeez.cloud -d www.tarmeez.cloud --email elbarrahsimo@gmail.com --agree-tos --no-eff-email

# 5. Restore production configuration and reload (Step C)
echo "-> Restoring production Nginx config..."
if [ -f "nginx/conf.d/default.conf.bak" ]; then
    mv nginx/conf.d/default.conf.bak nginx/conf.d/default.conf
else
    echo "Warning: Production config backup not found. Please ensure default.conf is correct."
fi

echo "-> Reloading containers with production SSL setup..."
docker-compose up -d --force-recreate nginx

echo "========================================"
echo "  SSL Initialization Complete! "
echo "========================================"
