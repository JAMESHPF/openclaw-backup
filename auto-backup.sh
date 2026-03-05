#!/bin/bash

# OpenClaw Auto Backup Script
# Automatically backs up OpenClaw, uploads to GitHub, and notifies agent

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config-full.json}"
BACKUP_NAME="auto-backup-$(date +%Y%m%d-%H%M%S)"
GITHUB_REPO="${OPENCLAW_BACKUP_GITHUB_REPO:-}"
NOTIFY_AGENT="${OPENCLAW_BACKUP_NOTIFY_AGENT:-atlas}"
NOTIFY_CHANNEL="${OPENCLAW_BACKUP_NOTIFY_CHANNEL:-telegram}"
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

# Send notification to OpenClaw agent
notify_agent() {
    local message="$1"
    local is_error="${2:-false}"

    if [ -z "$NOTIFY_AGENT" ]; then
        warn "No agent configured for notifications"
        return 0
    fi

    # Check if OpenClaw gateway is running
    if ! pgrep -f "openclaw gateway" > /dev/null 2>&1; then
        warn "OpenClaw gateway is not running, skipping agent notification"
        return 0
    fi

    log "Sending notification to agent: $NOTIFY_AGENT"

    # Send message to agent
    if openclaw agent \
        --agent "$NOTIFY_AGENT" \
        --message "$message" \
        --deliver \
        --channel "$NOTIFY_CHANNEL" \
        > /dev/null 2>&1; then
        log "Agent notification sent successfully"
    else
        warn "Failed to send agent notification"
    fi
}

# Main backup process
main() {
    log "Starting automatic OpenClaw backup..."

    # Run backup
    log "Creating backup: $BACKUP_NAME"
    if ! "$SCRIPT_DIR/backup.sh" --config "$CONFIG_FILE" "$BACKUP_NAME" > /tmp/openclaw-backup.log 2>&1; then
        error "Backup failed"

        # Notify agent of failure
        notify_agent "❌ OpenClaw 自动备份失败

时间: $(date '+%Y-%m-%d %H:%M:%S')
错误: 请查看日志 ~/.openclaw/logs/auto-backup.log" true

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
                GITHUB_STATUS="✅ 已上传到 GitHub: $GITHUB_REPO"
            else
                warn "Failed to upload to GitHub"
                GITHUB_STATUS="⚠️ GitHub 上传失败"
            fi
        else
            warn "gh CLI not installed, skipping GitHub upload"
            GITHUB_STATUS="⚠️ gh CLI 未安装，跳过上传"
        fi
    fi

    # Cleanup old backups
    log "Cleaning up old backups (keeping last $KEEP_BACKUPS)"
    if ! "$SCRIPT_DIR/cleanup.sh" --keep "$KEEP_BACKUPS" > /dev/null 2>&1; then
        warn "Cleanup failed"
    fi

    # Build success message
    local message="✅ OpenClaw 自动备份成功

📦 备份文件: $BACKUP_NAME
📊 文件大小: $BACKUP_SIZE
⏰ 备份时间: $(date '+%Y-%m-%d %H:%M:%S')
💾 保留数量: $KEEP_BACKUPS 个"

    if [ -n "$GITHUB_STATUS" ]; then
        message="$message
$GITHUB_STATUS"
    fi

    message="$message

📁 备份位置: ~/.openclaw/backups/
📝 日志文件: ~/.openclaw/logs/auto-backup.log"

    # Send success notification to agent
    notify_agent "$message"

    log "Automatic backup completed successfully"
}

# Run main function
main "$@"
