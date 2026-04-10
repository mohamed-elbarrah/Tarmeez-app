#!/bin/sh
set -e

# Use the domain from environment variable if available, otherwise default to tarmeez.cloud
DOMAIN=${DOMAIN:-tarmeez.cloud}
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

echo "-> Checking for SSL certificates for $DOMAIN..."

if [ ! -f "$CERT_FILE" ]; then
    echo "-> SSL certificates not found at $CERT_FILE"
    echo "-> Generating temporary self-signed 'dummy' certificate..."
    
    mkdir -p "$CERT_DIR"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=$DOMAIN"
    
    echo "-> Dummy certificates generated at $CERT_DIR"
else
    echo "-> Valid SSL certificates found at $CERT_FILE"
fi

echo "-> Testing Nginx configuration..."
nginx -t

echo "-> Starting Nginx and reload loop..."
# Run reload loop in background
(while :; do sleep 6h; nginx -s reload; done) &

# Start Nginx in foreground
exec nginx -g "daemon off;"
