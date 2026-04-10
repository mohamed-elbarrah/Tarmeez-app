#!/bin/bash

# ==============================================================================
# Tarmeez Hub - Robust Deployment Script (Backup, Zero-Downtime & Notifications)
# ==============================================================================

# Exit on any error
set -e

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
WEBHOOK_URL="${DEPLOY_WEBHOOK}" # Set in .env

# Logging and Notifications
log() {
  echo -e "\n\033[1;32m[DEPLOY] $1\033[0m"
}

error_log() {
  local message="$1"
  echo -e "\n\033[1;31m[ERROR] $message\033[0m"
  notify_failure "$message"
}

notify_failure() {
  local message="$1"
  if [ -n "$WEBHOOK_URL" ]; then
    log "Sending failure notification to webhook..."
    curl -X POST -H "Content-Type: application/json" \
      -d "{\"content\": \"❌ **Deployment Failed!**\n**Error:** $message\n**Server:** $(hostname)\n**Time:** $(date)\"}" \
      "$WEBHOOK_URL" || log "Failed to send notification."
  fi
}

notify_success() {
  if [ -n "$WEBHOOK_URL" ]; then
    log "Sending success notification to webhook..."
    curl -X POST -H "Content-Type: application/json" \
      -d "{\"content\": \"✅ **Deployment Successful!**\n**Server:** $(hostname)\n**Version:** $(git rev-parse --short HEAD)\"}" \
      "$WEBHOOK_URL" || log "Failed to send notification."
  fi
}

# Trap unexpected errors
trap 'if [ $? -ne 0 ]; then error_log "Unexpected error occurred at line $LINENO"; fi' EXIT

# 0. Preparation
mkdir -p "$BACKUP_DIR"

# 1. Update Root and Submodules
log "Pulling latest changes for Root and Submodules..."
git pull origin main
git submodule update --init --recursive --remote

# 2. Database Backup (Safety First)
log "Creating pre-deployment database backup..."
BACKUP_FILE="$BACKUP_DIR/platform_db_$TIMESTAMP.sql"
if docker compose ps | grep -q postgres_main; then
  # Use -T for non-interactive shell (no TTY)
  if ! docker compose exec -T postgres_main pg_dump -U "${DB_USER:-postgres}" platform_db > "$BACKUP_FILE"; then
    error_log "Database backup failed! Aborting deployment for safety."
    exit 1
  fi
  log "Backup created: $BACKUP_FILE"
else
  log "Warning: postgres_main container not found. Skipping backup."
fi

# 3. Sequential Build (Resource Management)
log "Building services sequentially..."

log "Building Server..."
if ! docker compose build --no-cache server; then
  error_log "Server build failed!"
  exit 1
fi

log "Building Client..."
if ! docker compose build --no-cache client; then
  error_log "Client build failed!"
  exit 1
fi

# 4. Zero-Downtime Swap
log "Performing Zero-Downtime Swap..."

log "Updating Server and Worker..."
docker compose up -d --build --no-deps server worker

log "Updating Client..."
docker compose up -d --build --no-deps client

# 5. Post-Deploy Hooks & Health Checks
log "Waiting for server to be healthy..."
MAX_RETRIES=15
COUNT=0
HEALTH_URL="http://localhost:8000/api/health"

until docker compose exec -T server wget --spider -q "$HEALTH_URL" || [ $COUNT -eq $MAX_RETRIES ]; do
  sleep 5
  COUNT=$((COUNT+1))
  log "Waiting for health check... ($COUNT/$MAX_RETRIES)"
done

if [ $COUNT -lt $MAX_RETRIES ]; then
  log "Server is healthy. Verifying migrations..."
  if ! docker compose exec -T server npx prisma migrate deploy; then
    error_log "Prisma migration failed!"
    exit 1
  fi
  log "Migrations verified."
else
  error_log "Server failed health check after deployment!"
  docker compose logs server --tail 50
  exit 1
fi

# 6. Cleanup & Completion
log "Pruning old images..."
docker image prune -f

log "===================================================================="
log "  Deployment Successful! "
log "===================================================================="

notify_success

# Unset trap on successful exit
trap - EXIT
