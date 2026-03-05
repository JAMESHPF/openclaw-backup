#!/bin/bash
# OpenClaw Backup Cleanup Tool
# Cleanup old backup files, keep last N backups
# Usage: ./cleanup.sh [--keep N]

set -e

OPENCLAW_DIR="$HOME/.openclaw"
BACKUPS_DIR="$OPENCLAW_DIR/backups"
KEEP_COUNT=10  # defaultKeep last 10 backups

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep)
            KEEP_COUNT="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
OpenClaw Backup Cleanup Tool

Usage: $0 [选项]

Options:
  --keep N          Keep last N backups (default: 10)
  --help, -h        Show this help

Examples:
  $0                # Keep last 10 backups
  $0 --keep 5       # Keep last 5 backups
  $0 --keep 20      # Keep last 20 backups

Backup directory: $BACKUPS_DIR
EOF
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Use --help for help"
            exit 1
            ;;
    esac
done

# CheckBackup directory
if [ ! -d "$BACKUPS_DIR" ]; then
    echo "📁 Backup directorynot found: $BACKUPS_DIR"
    echo "   No backups to clean"
    exit 0
fi

# CountBackup filecount
BACKUP_COUNT=$(find "$BACKUPS_DIR" -name "openclaw-backup-*.tar.gz" -type f | wc -l | tr -d ' ')

if [ "$BACKUP_COUNT" -eq 0 ]; then
    echo "📁 Backup directoryis empty，No backups to clean"
    exit 0
fi

echo "🔍 Found $BACKUP_COUNT \ Backup file"
echo "📋 Keep last $KEEP_COUNT backups"

if [ "$BACKUP_COUNT" -le "$KEEP_COUNT" ]; then
    echo "✅ Backup count within limit, no cleanup needed"
    exit 0
fi

# 计算需要删除\ count
DELETE_COUNT=$((BACKUP_COUNT - KEEP_COUNT))
echo "🗑️  Will delete $DELETE_COUNT old backups"
echo ""

# 列出将要删除\ 文件
echo "Backups to be deleted:"
find "$BACKUPS_DIR" -name "openclaw-backup-*.tar.gz" -type f -print0 | \
    xargs -0 ls -t | \
    tail -n "$DELETE_COUNT" | \
    while read -r file; do
        SIZE=$(du -h "$file" | cut -f1)
        echo "  - $(basename "$file") ($SIZE)"
    done

echo ""
read -p "Confirm deletion? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 0
fi

# Delete old backups
echo "🗑️  Starting deletion..."
DELETED=0

# 使用数组存储要删除\ 文件
mapfile -t FILES_TO_DELETE < <(find "$BACKUPS_DIR" -name "openclaw-backup-*.tar.gz" -type f -print0 | xargs -0 ls -t | tail -n "$DELETE_COUNT")

for file in "${FILES_TO_DELETE[@]}"; do
    if [ -f "$file" ]; then
        # Also delete checksum file
        rm -f "$file" "${file}.sha256"
        echo "  ✓ deleted: $(basename "$file")"
        DELETED=$((DELETED + 1))
    fi
done

echo ""
echo "✅ Cleanupcomplete，deleted $DELETE_COUNT old backups"
echo "📁 Currently keeping $KEEP_COUNT backups"
