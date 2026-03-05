#!/bin/bash
# OpenClaw Restore Tool
# 支持Config file驱动，自动路径修复，适配任何环境
# Usage: ./restore.sh <backup-file.tar.gz> [--config path/to/config.json]

set -e

# default配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
BACKUP_FILE=""
VERBOSE=false
DRY_RUN=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            cat << EOF
OpenClaw Restore Tool

Usage: $0 <backup-file.tar.gz> [选项]

Options:
  --config FILE     SpecifyConfig file (default: backup-config.json)
  --verbose, -v     Show verbose output
  --dry-run         Preview restore, no actualExecute
  --help, -h        Show this help

Examples:
  $0 openclaw-backup-20260305.tar.gz
  $0 backup.tar.gz --config custom.json
  $0 backup.tar.gz --dry-run --verbose

Config fileformat see backup-config.json
EOF
            exit 0
            ;;
        *)
            if [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE="$1"
            fi
            shift
            ;;
    esac
done

# CheckBackup file
if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Please specify backup file"
    echo "Usage: $0 <backup-file.tar.gz>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup filenot found: $BACKUP_FILE"
    exit 1
fi

# 验证校验和（如果存在）
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    echo "🔐 Verifying backup integrity..."
    if command -v sha256sum &> /dev/null; then
        if sha256sum -c "$CHECKSUM_FILE" 2>/dev/null; then
            echo "   ✓ Checksum verification passed"
        else
            echo "   ❌ Checksum verification failed! Backup file may be corrupted"
            read -p "Continue restore? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "❌ Restore cancelled"
                exit 1
            fi
        fi
    elif command -v shasum &> /dev/null; then
        if shasum -a 256 -c "$CHECKSUM_FILE" 2>/dev/null; then
            echo "   ✓ Checksum verification passed"
        else
            echo "   ❌ Checksum verification failed! Backup file may be corrupted"
            read -p "Continue restore? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "❌ Restore cancelled"
                exit 1
            fi
        fi
    fi
else
    echo "⚠️  Checksum file not found, skipping integrity verification"
fi

# CheckConfig file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "Using default config..."
    OPENCLAW_DIR="$HOME/.openclaw"
    BACKUP_EXISTING=true
    AUTO_FIX_PATHS=true
else
    # Read config
    if command -v jq &> /dev/null; then
        JSON_PARSER="jq"
    elif command -v python3 &> /dev/null; then
        JSON_PARSER="python3"
    else
        echo "❌ jq or python3 required for config parsing"
        exit 1
    fi

    # 解析配置\ 辅助函数
    get_config() {
        local key="$1"
        local default="$2"

        if [ "$JSON_PARSER" = "jq" ]; then
            local value=$(jq -r "$key // \"$default\"" "$CONFIG_FILE")
        else
            local value=$(python3 -c "import json,sys; data=json.load(open('$CONFIG_FILE')); print(data$key if data$key else '$default')" 2>/dev/null || echo "$default")
        fi

        echo "$value"
    }

    OPENCLAW_DIR=$(get_config '.openclaw_dir' "$HOME/.openclaw")
    OPENCLAW_DIR="${OPENCLAW_DIR/#\~/$HOME}"
    BACKUP_EXISTING=$(get_config '.restore.backup_existing' 'true')
    AUTO_FIX_PATHS=$(get_config '.restore.auto_fix_paths' 'true')
fi

TEMP_DIR="/tmp/openclaw-restore-$$"

echo "🔄 Starting OpenClaw configuration restore..."
[ "$VERBOSE" = true ] && echo "   Backup file: $BACKUP_FILE"
[ "$VERBOSE" = true ] && echo "   Target directory: $OPENCLAW_DIR"
[ "$VERBOSE" = true ] && echo "   Config file: $CONFIG_FILE"
[ "$DRY_RUN" = true ] && echo "   ⚠️  预览模式 (不会实际修改文件)"

# Backup existing config
if [ "$BACKUP_EXISTING" = "true" ] && [ -d "$OPENCLAW_DIR" ] && [ "$DRY_RUN" = false ]; then
    BACKUP_OLD="$OPENCLAW_DIR.before-restore-$(date +%Y%m%d-%H%M%S)"
    echo "💾 Backing up existing config to $BACKUP_OLD..."
    mv "$OPENCLAW_DIR" "$BACKUP_OLD"
    echo "   ✓ Existing config backed up"
fi

# Extract备份
echo "📦 ExtractBackup file..."
mkdir -p "$TEMP_DIR"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# FindBackup directory
BACKUP_CONTENT=$(find "$TEMP_DIR" -type d -name "openclaw-backup-*" | head -1)

if [ -z "$BACKUP_CONTENT" ]; then
    echo "❌ Backup file格式错误"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# ShowBackup info
if [ -f "$BACKUP_CONTENT/BACKUP_INFO.txt" ]; then
    echo ""
    echo "📋 Backup info:"
    cat "$BACKUP_CONTENT/BACKUP_INFO.txt"
    echo ""
fi

# 预览模式：ShowFiles to be restored
if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "📁 Files to be restored:"
    find "$BACKUP_CONTENT" -type f -o -type d | sed "s|$BACKUP_CONTENT|  |" | head -50
    echo ""
    echo "💡 Use without --dry-run to actually restore"
    rm -rf "$TEMP_DIR"
    exit 0
fi

# CreateTarget directory
mkdir -p "$OPENCLAW_DIR"

# Restoring files
echo "📁 Restoring files..."
cp -r "$BACKUP_CONTENT"/* "$OPENCLAW_DIR/"
echo "   ✓ Files restored"

# Auto-fixing paths
if [ "$AUTO_FIX_PATHS" = "true" ] && [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
    echo "🔧 Auto-fixing paths..."

    # Replace placeholders with actual paths
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|{{OPENCLAW_DIR}}|$OPENCLAW_DIR|g" "$OPENCLAW_DIR/openclaw.json"
        sed -i '' "s|{{HOME}}|$HOME|g" "$OPENCLAW_DIR/openclaw.json"
    else
        sed -i "s|{{OPENCLAW_DIR}}|$OPENCLAW_DIR|g" "$OPENCLAW_DIR/openclaw.json"
        sed -i "s|{{HOME}}|$HOME|g" "$OPENCLAW_DIR/openclaw.json"
    fi

    echo "   ✓ Paths fixed"

    # Verify path fix
    if grep -q "{{OPENCLAW_DIR}}" "$OPENCLAW_DIR/openclaw.json" 2>/dev/null; then
        echo "   ⚠️  Warning: unreplaced placeholders remain"
    fi

    if grep -q "/root/.openclaw" "$OPENCLAW_DIR/openclaw.json" 2>/dev/null; then
        echo "   ⚠️  Warning: /root path detected, may need manual fix"
    fi
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Restore complete！"
echo ""
echo "🔄 Next steps:"
echo "   1. Restart OpenClaw Gateway:"
echo "      openclaw gateway restart"
echo ""
echo "   2. Check status:"
echo "      openclaw status"
echo ""
echo "   3. To re-pair Telegram Bot:"
echo "      - Send to each bot /start"
echo "      - Get pairing code"
echo "      - Execute: openclaw pairing approve telegram <code>"
echo ""

# Verifying critical files
echo "🔍 Verifying critical files:"
CRITICAL_FILES=("openclaw.json" ".env")
ALL_OK=true

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$OPENCLAW_DIR/$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file (missing)"
        ALL_OK=false
    fi
done

if [ "$ALL_OK" = false ]; then
    echo ""
    echo "⚠️  Warning: 部分关键文件missing，请Check备份完整性"
fi
