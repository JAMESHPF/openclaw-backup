#!/bin/bash

# OpenClaw Auto Backup Script
# Automatically backs up OpenClaw, uploads to GitHub, and notifies via agent

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config-full.json}"
BACKUP_NAME="auto-backup-$(date +%Y%m%d-%H%M%S)"
GITHUB_REPO="${OPENCLAW_BACKUP_GITHUB_REPO:-}"
NOTIFY_AGENT="${OPENCLAW_BACKUP_NOTIFY_AGENT:-atlas}"
NOTIFY_TARGET="${OPENCLAW_BACKUP_NOTIFY_TARGET:-}"
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

# Send notification via openclaw message send
notify() {
    local message="$1"

    if [ -z "$NOTIFY_AGENT" ] || [ -z "$NOTIFY_TARGET" ]; then
        warn "Notification not configured (agent=$NOTIFY_AGENT, target=$NOTIFY_TARGET)"
        return 0
    fi

    # Check if OpenClaw gateway is running
    if ! pgrep -f "openclaw.*gateway" > /dev/null 2>&1; then
        warn "OpenClaw gateway is not running, skipping notification"
        return 0
    fi

    log "Sending notification via $NOTIFY_AGENT to $NOTIFY_TARGET"

    if openclaw message send \
        --channel telegram \
        --account "$NOTIFY_AGENT" \
        --target "$NOTIFY_TARGET" \
        --message "$message" \
        > /dev/null 2>&1; then
        log "Notification sent successfully"
    else
        warn "Failed to send notification"
    fi
}

# Main backup process
main() {
    log "Starting automatic OpenClaw backup..."

    # Run backup
    log "Creating backup: $BACKUP_NAME"
    if ! "$SCRIPT_DIR/backup.sh" --config "$CONFIG_FILE" --yes "$BACKUP_NAME" > /tmp/openclaw-backup.log 2>&1; then
        error "Backup failed"

        notify "❌ OpenClaw 自动备份失败

⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')
❗ 请查看日志: ~/.openclaw/logs/auto-backup.log"

        exit 1
    fi

    BACKUP_FILE="$HOME/.openclaw/backups/openclaw-${BACKUP_NAME}.tar.gz"
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

    log "Backup created successfully: $BACKUP_SIZE"

    # Upload to GitHub if configured
    GITHUB_STATUS=""
    if [ -n "$GITHUB_REPO" ]; then
        log "Uploading to GitHub: $GITHUB_REPO"

        if command -v gh >/dev/null 2>&1; then
            RELEASE_TAG="backup-$(date +%Y%m%d)"

            if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
                gh release upload "$RELEASE_TAG" "$BACKUP_FILE" \
                    --repo "$GITHUB_REPO" \
                    --clobber \
                    > /dev/null 2>&1
            else
                gh release create "$RELEASE_TAG" "$BACKUP_FILE" \
                    --repo "$GITHUB_REPO" \
                    --title "Backup $(date '+%Y-%m-%d')" \
                    --notes "Automatic backup created at $(date '+%Y-%m-%d %H:%M:%S')" \
                    > /dev/null 2>&1
            fi

            if [ $? -eq 0 ]; then
                log "Uploaded to GitHub successfully"
                GITHUB_STATUS="🔗 GitHub: $GITHUB_REPO"
            else
                warn "Failed to upload to GitHub"
                GITHUB_STATUS="⚠️ GitHub 上传失败"
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

    # Build success message
    local message="✅ OpenClaw 自动备份成功

📦 备份: $BACKUP_NAME
📊 大小: $BACKUP_SIZE
⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"

    if [ -n "$GITHUB_STATUS" ]; then
        message="$message
$GITHUB_STATUS"
    fi

    # Send success notification
    notify "$message"

    log "Automatic backup completed successfully"
}

# Run main function
main "$@"
