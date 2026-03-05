#!/bin/bash

# OpenClaw Auto Backup Script
# Automatically backs up OpenClaw, uploads to GitHub, and sends Telegram notification

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config-full.json}"
BACKUP_NAME="auto-backup-$(date +%Y%m%d-%H%M%S)"
GITHUB_REPO="${OPENCLAW_BACKUP_GITHUB_REPO:-}"
TELEGRAM_BOT_TOKEN="${OPENCLAW_BACKUP_TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_ID="${OPENCLAW_BACKUP_TELEGRAM_CHAT_ID:-}"
KEEP_BACKUPS="${OPENCLAW_BACKUP_KEEP:-10}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

# Send Telegram notification
send_telegram() {
    local message="$1"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        warn "Telegram credentials not configured, skipping notification"
        return 0
    fi

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=Markdown" \
        > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        log "Telegram notification sent"
    else
        warn "Failed to send Telegram notification"
    fi
}

# Main backup process
main() {
    log "Starting automatic OpenClaw backup..."

    # Run backup
    log "Creating backup: $BACKUP_NAME"
    if ! "$SCRIPT_DIR/backup.sh" --config "$CONFIG_FILE" "$BACKUP_NAME" > /tmp/openclaw-backup.log 2>&1; then
        error "Backup failed"
        send_telegram "❌ *OpenClaw Backup Failed*%0A%0ATime: $(date '+%Y-%m-%d %H:%M:%S')%0AError: Check logs for details"
        exit 1
    fi

    BACKUP_FILE="$HOME/.openclaw/backups/openclaw-${BACKUP_NAME}.tar.gz"
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

    log "Backup created successfully: $BACKUP_SIZE"

    # Upload to GitHub if configured
    if [ -n "$GITHUB_REPO" ]; then
        log "Uploading to GitHub: $GITHUB_REPO"

        if command -v gh >/dev/null 2>&1; then
            RELEASE_TAG="backup-$(date +%Y%m%d)"

            # Create or update release
            if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
                # Release exists, upload asset
                gh release upload "$RELEASE_TAG" "$BACKUP_FILE" \
                    --repo "$GITHUB_REPO" \
                    --clobber \
                    > /dev/null 2>&1
            else
                # Create new release
                gh release create "$RELEASE_TAG" "$BACKUP_FILE" \
                    --repo "$GITHUB_REPO" \
                    --title "Backup $(date '+%Y-%m-%d')" \
                    --notes "Automatic backup created at $(date '+%Y-%m-%d %H:%M:%S')" \
                    > /dev/null 2>&1
            fi

            if [ $? -eq 0 ]; then
                log "Uploaded to GitHub successfully"
            else
                warn "Failed to upload to GitHub"
            fi
        else
            warn "gh CLI not installed, skipping GitHub upload"
        fi
    fi

    # Cleanup old backups
    log "Cleaning up old backups (keeping last $KEEP_BACKUPS)"
    if ! "$SCRIPT_DIR/cleanup.sh" --keep "$KEEP_BACKUPS" > /dev/null 2>&1; then
        warn "Cleanup failed"
    fi

    # Send success notification
    local message="✅ *OpenClaw Backup Successful*%0A%0A"
    message+="📦 Backup: \`$BACKUP_NAME\`%0A"
    message+="📊 Size: $BACKUP_SIZE%0A"
    message+="⏰ Time: $(date '+%Y-%m-%d %H:%M:%S')%0A"

    if [ -n "$GITHUB_REPO" ]; then
        message+="%0A🔗 GitHub: $GITHUB_REPO"
    fi

    send_telegram "$message"

    log "Automatic backup completed successfully"
}

# Run main function
main "$@"
