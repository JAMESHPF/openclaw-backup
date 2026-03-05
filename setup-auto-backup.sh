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

    # Remove cron job
    if crontab -l 2>/dev/null | grep -q "auto-backup-wrapper.sh"; then
        crontab -l 2>/dev/null | grep -v "auto-backup-wrapper.sh" | crontab -
        echo -e "${GREEN}✓ Cron job removed${NC}"
    else
        echo "No cron job found"
    fi

    # Remove configuration
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

# Collect configuration
echo "Let's configure automatic backups for OpenClaw."
echo ""

# Backup schedule
echo "1. Backup Schedule"
echo "   a) Daily (recommended)"
echo "   b) Weekly"
echo "   c) Custom cron expression"
read -p "Choose schedule (a/b/c): " schedule_choice

case "$schedule_choice" in
    a|A)
        CRON_SCHEDULE="0 2 * * *"  # 2 AM daily
        SCHEDULE_DESC="Daily at 2:00 AM"
        ;;
    b|B)
        CRON_SCHEDULE="0 2 * * 0"  # 2 AM Sunday
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

# GitHub configuration
echo "2. GitHub Upload (optional)"
read -p "Do you want to upload backups to GitHub? (y/N): " use_github

if [[ "$use_github" =~ ^[Yy]$ ]]; then
    read -p "Enter GitHub repository (e.g., username/openclaw-backups): " GITHUB_REPO
else
    GITHUB_REPO=""
fi

echo ""

# Agent notification
echo "3. Agent Notification"
echo ""
echo "Available agents:"
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
    # Extract agent IDs from config
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
            print(f\"  - {agent['id']}\")
" 2>/dev/null
    fi
fi

echo ""
read -p "Which agent should receive backup notifications? (default: atlas): " NOTIFY_AGENT
NOTIFY_AGENT="${NOTIFY_AGENT:-atlas}"

read -p "Which channel to use for notifications? (default: telegram): " NOTIFY_CHANNEL
NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-telegram}"

echo ""

# Backup retention
read -p "How many backups to keep locally? (default: 10): " KEEP_BACKUPS
KEEP_BACKUPS="${KEEP_BACKUPS:-10}"

echo ""

# Save configuration
cat > "$HOME/.openclaw/.backup-env" <<EOF
# OpenClaw Auto Backup Configuration
# Generated at $(date)

# GitHub repository for backup uploads (leave empty to disable)
export OPENCLAW_BACKUP_GITHUB_REPO="$GITHUB_REPO"

# Agent to receive backup notifications
export OPENCLAW_BACKUP_NOTIFY_AGENT="$NOTIFY_AGENT"

# Channel for agent notifications (telegram, discord, etc.)
export OPENCLAW_BACKUP_NOTIFY_CHANNEL="$NOTIFY_CHANNEL"

# Number of local backups to keep
export OPENCLAW_BACKUP_KEEP="$KEEP_BACKUPS"
EOF

chmod 600 "$HOME/.openclaw/.backup-env"

echo -e "${GREEN}✓ Configuration saved to ~/.openclaw/.backup-env${NC}"
echo ""

# Setup cron job
echo "Setting up cron job..."

# Create wrapper script that sources environment
WRAPPER_SCRIPT="$HOME/.openclaw/openclaw-backup/auto-backup-wrapper.sh"
cat > "$WRAPPER_SCRIPT" <<'EOF'
#!/bin/bash
# Auto-generated wrapper script for OpenClaw auto backup

# Source environment variables
if [ -f "$HOME/.openclaw/.backup-env" ]; then
    source "$HOME/.openclaw/.backup-env"
fi

# Run backup
"$HOME/.openclaw/openclaw-backup/auto-backup.sh" >> "$HOME/.openclaw/logs/auto-backup.log" 2>&1
EOF

chmod +x "$WRAPPER_SCRIPT"

# Create logs directory
mkdir -p "$HOME/.openclaw/logs"

# Add to crontab
CRON_ENTRY="$CRON_SCHEDULE $WRAPPER_SCRIPT"

# Check if cron entry already exists
if crontab -l 2>/dev/null | grep -q "auto-backup-wrapper.sh"; then
    # Remove old entry
    crontab -l 2>/dev/null | grep -v "auto-backup-wrapper.sh" | crontab -
fi

# Add new entry
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

echo -e "${GREEN}✓ Cron job configured${NC}"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Configuration:"
echo "  Schedule: $SCHEDULE_DESC"
echo "  GitHub: ${GITHUB_REPO:-Disabled}"
echo "  Notify Agent: $NOTIFY_AGENT (via $NOTIFY_CHANNEL)"
echo "  Keep backups: $KEEP_BACKUPS"
echo ""
echo "Logs: ~/.openclaw/logs/auto-backup.log"
echo ""
echo "To test the backup now, run:"
echo "  $SCRIPT_DIR/auto-backup.sh"
echo ""
echo "To disable auto backup, run:"
echo "  $SCRIPT_DIR/setup-auto-backup.sh --disable"
echo ""

# Offer to run test backup
read -p "Do you want to run a test backup now? (y/N): " run_test

if [[ "$run_test" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Running test backup..."
    "$SCRIPT_DIR/auto-backup.sh"
fi
