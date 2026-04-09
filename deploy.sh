#!/bin/bash
set -e

echo "========================================"
echo "  Tarmeez Hub - Smart Deployment Script"
echo "========================================"

# 0. Permission & Path Hardening
echo "[0/5] Setting up persistent directories..."
mkdir -p /opt/tarmeez/data/postgres_main
mkdir -p /opt/tarmeez/data/postgres_analytics
mkdir -p /opt/tarmeez/data/redis
mkdir -p /opt/tarmeez/data/uploads
mkdir -p /opt/tarmeez/data/certbot/conf
mkdir -p /opt/tarmeez/data/certbot/www

# 1. Pull latest code
echo "[1/5] Pulling latest code from git..."
git pull origin main

# 2. Git Submodule Synchronization
echo "[2/5] Synchronizing submodules..."
git submodule update --init --recursive --remote

# 3. Build new Docker images while old ones remain running
echo "[3/5] Building new Docker images..."
docker-compose build --pull

# 4. Swap containers (Zero-Downtime Swap via docker-compose up)
# The old worker will receive SIGTERM and gracefully shut down (30s grace period)
echo "[4/5] Starting new containers and removing orphans..."
docker-compose up -d --remove-orphans

# 5. Clean up old images to save disk space
echo "[5/5] Pruning old Docker images..."
docker image prune -f

echo "========================================"
echo "  Deployment Complete! "
echo "========================================"
