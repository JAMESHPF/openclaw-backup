#!/bin/bash

# OpenClaw Auto Backup Setup Script
# Sets up automatic backups with cron

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Handle --disable flag
if [ "$1" = "--disable" ]; then
    echo -e "${YELLOW}Disabling auto backup...${NC}"

    if crontab -l 2>/dev/null | grep -q "auto-backup-wrapper.sh"; then
        crontab -l 2>/dev/null | grep -v "auto-backup-wrapper.sh" | crontab -
        echo -e "${GREEN}✓ Cron job removed${NC}"
    else
        echo "No cron job found"
    fi

    if [ -f "$HOME/.openclaw/.backup-env" ]; then
        rm "$HOME/.openclaw/.backup-env"
        echo -e "${GREEN}✓ Configuration removed${NC}"
    fi

    echo ""
    echo "Auto backup has been disabled."
    exit 0
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  OpenClaw Auto Backup Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if already configured
if [ -f "$HOME/.openclaw/.backup-env" ]; then
    echo -e "${YELLOW}Auto backup is already configured.${NC}"
    read -p "Do you want to reconfigure? (y/N): " reconfigure
    if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo "Let's configure automatic backups for OpenClaw."
echo ""

# === 1. Backup schedule ===
echo "1. Backup Schedule"
echo "   a) Daily (recommended)"
echo "   b) Weekly"
echo "   c) Custom cron expression"
read -p "Choose schedule (a/b/c): " schedule_choice

case "$schedule_choice" in
    a|A)
        CRON_SCHEDULE="0 2 * * *"
        SCHEDULE_DESC="Daily at 2:00 AM"
        ;;
    b|B)
        CRON_SCHEDULE="0 2 * * 0"
        SCHEDULE_DESC="Weekly on Sunday at 2:00 AM"
        ;;
    c|C)
        read -p "Enter cron expression: " CRON_SCHEDULE
        SCHEDULE_DESC="Custom: $CRON_SCHEDULE"
        ;;
    *)
        echo "Invalid choice, using daily schedule"
        CRON_SCHEDULE="0 2 * * *"
        SCHEDULE_DESC="Daily at 2:00 AM"
        ;;
esac

echo ""

# === 2. GitHub ===
echo "2. GitHub Upload (optional)"
read -p "Upload backups to GitHub? (y/N): " use_github

if [[ "$use_github" =~ ^[Yy]$ ]]; then
    read -p "Enter GitHub repository (e.g., username/openclaw-backups): " GITHUB_REPO
else
    GITHUB_REPO=""
fi

echo ""

# === 3. Agent notification ===
echo "3. Notification"
echo ""
echo "Available agents:"
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
    if command -v jq >/dev/null 2>&1; then
        jq -r '.agents.list[]?.id // empty' "$HOME/.openclaw/openclaw.json" 2>/dev/null | while read -r agent_id; do
            echo "  - $agent_id"
        done
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
with open('$HOME/.openclaw/openclaw.json') as f:
    config = json.load(f)
    for agent in config.get('agents', {}).get('list', []):
        if 'id' in agent:
            print(f'  - {agent[\"id\"]}')
" 2>/dev/null
    fi
fi

echo ""
read -p "Which agent account to send notifications from? (default: atlas): " NOTIFY_AGENT
NOTIFY_AGENT="${NOTIFY_AGENT:-atlas}"

echo ""
echo "Enter your Telegram chat ID (your personal user ID)."
echo "You can get it from @userinfobot on Telegram."
read -p "Telegram chat ID: " NOTIFY_TARGET

if [ -z "$NOTIFY_TARGET" ]; then
    echo -e "${YELLOW}⚠️  No chat ID provided, notifications will be disabled${NC}"
fi

echo ""

# === 4. Retention ===
read -p "How many backups to keep locally? (default: 10): " KEEP_BACKUPS
KEEP_BACKUPS="${KEEP_BACKUPS:-10}"

echo ""

# Save configuration
cat > "$HOME/.openclaw/.backup-env" <<EOF
# OpenClaw Auto Backup Configuration
# Generated at $(date)

# GitHub repository for backup uploads (leave empty to disable)
export OPENCLAW_BACKUP_GITHUB_REPO="$GITHUB_REPO"

# Agent account to send notifications from
export OPENCLAW_BACKUP_NOTIFY_AGENT="$NOTIFY_AGENT"

# Telegram chat ID to send notifications to
export OPENCLAW_BACKUP_NOTIFY_TARGET="$NOTIFY_TARGET"

# Number of local backups to keep
export OPENCLAW_BACKUP_KEEP="$KEEP_BACKUPS"
EOF

chmod 600 "$HOME/.openclaw/.backup-env"

echo -e "${GREEN}✓ Configuration saved to ~/.openclaw/.backup-env${NC}"
echo ""

# Setup cron job
echo "Setting up cron job..."

WRAPPER_SCRIPT="$HOME/.openclaw/openclaw-backup/auto-backup-wrapper.sh"
cat > "$WRAPPER_SCRIPT" <<'WEOF'
#!/bin/bash
# Auto-generated wrapper script for OpenClaw auto backup

# Source environment variables
if [ -f "$HOME/.openclaw/.backup-env" ]; then
    source "$HOME/.openclaw/.backup-env"
fi

# Ensure PATH includes common locations
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Run backup
"$HOME/.openclaw/openclaw-backup/auto-backup.sh" >> "$HOME/.openclaw/logs/auto-backup.log" 2>&1
WEOF

chmod +x "$WRAPPER_SCRIPT"

mkdir -p "$HOME/.openclaw/logs"

# Update crontab
if crontab -l 2>/dev/null | grep -q "auto-backup-wrapper.sh"; then
    crontab -l 2>/dev/null | grep -v "auto-backup-wrapper.sh" | crontab -
fi

(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $WRAPPER_SCRIPT") | crontab -

echo -e "${GREEN}✓ Cron job configured${NC}"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Configuration:"
echo "  Schedule:    $SCHEDULE_DESC"
echo "  GitHub:      ${GITHUB_REPO:-Disabled}"
echo "  Notify via:  $NOTIFY_AGENT → ${NOTIFY_TARGET:-Disabled}"
echo "  Keep:        $KEEP_BACKUPS backups"
echo ""
echo "Commands:"
echo "  Test now:    $SCRIPT_DIR/auto-backup.sh"
echo "  View logs:   tail -f ~/.openclaw/logs/auto-backup.log"
echo "  Disable:     $SCRIPT_DIR/setup-auto-backup.sh --disable"
echo ""

# Offer to run test backup
read -p "Run a test backup now? (y/N): " run_test

if [[ "$run_test" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Running test backup..."
    source "$HOME/.openclaw/.backup-env"
    "$SCRIPT_DIR/auto-backup.sh"
fi
