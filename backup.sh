#!/bin/bash
# OpenClaw Backup Tool
# Config-driven, auto-discovery, universal compatibility
# Usage: ./backup.sh [backup-name] [--config path/to/config.json]

set -e

# default配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
BACKUP_NAME=""
VERBOSE=false
AUTO_YES=false

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
        --yes|-y)
            AUTO_YES=true
            shift
            ;;
        --help|-h)
            cat << EOF
OpenClaw Backup Tool

Usage: $0 [backup-name] [options]

Options:
  --config FILE     Specify config file (default: config.json)
  --verbose, -v     Show verbose output
  --yes, -y         Skip confirmation prompts (for automation)
  --help, -h        Show this help

Examples:
  $0                          # Use default config with timestamp
  $0 my-backup                # Specify backup name
  $0 --config custom.json     # Use custom config
  $0 my-backup --verbose      # Show verbose output

Config file format see config.json
EOF
            exit 0
            ;;
        *)
            if [ -z "$BACKUP_NAME" ]; then
                BACKUP_NAME="$1"
            fi
            shift
            ;;
    esac
done

# CheckConfig file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    echo "Please create config file or use --config to specify path"
    exit 1
fi

# Read config (使用 jq 或 python)
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

# Read config
OPENCLAW_DIR=$(get_config '.openclaw_dir' "$HOME/.openclaw")
OPENCLAW_DIR="${OPENCLAW_DIR/#\~/$HOME}"  # 展开 ~
AUTO_DISCOVER=$(get_config '.backup.auto_discover_workspaces' 'true')
WORKSPACE_PATTERN=$(get_config '.backup.workspace_pattern' 'workspace*')
INCLUDE_SHARED=$(get_config '.backup.include.shared' 'true')
INCLUDE_AGENTS=$(get_config '.backup.include.agents' 'false')
INCLUDE_CREDENTIALS=$(get_config '.backup.include.credentials' 'false')
INCLUDE_MEMORY=$(get_config '.backup.include.memory' 'true')
PATH_PLACEHOLDER_ENABLED=$(get_config '.backup.path_placeholders.enabled' 'true')

# Set backup name
if [ -z "$BACKUP_NAME" ]; then
    BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
fi

BACKUP_DIR="/tmp/openclaw-backup-$BACKUP_NAME"
ARCHIVE_NAME="openclaw-$BACKUP_NAME.tar.gz"

echo "🔄 Starting OpenClaw configuration backup..."
[ "$VERBOSE" = true ] && echo "   Config file: $CONFIG_FILE"
[ "$VERBOSE" = true ] && echo "   OpenClaw directory: $OPENCLAW_DIR"

# Check OpenClaw directory
if [ ! -d "$OPENCLAW_DIR" ]; then
    echo "❌ OpenClaw directorynot found: $OPENCLAW_DIR"
    exit 1
fi

# Check OpenClaw 是否正在运行
if pgrep -f "openclaw" > /dev/null 2>&1; then
    echo ""
    echo "⚠️  OpenClaw is running"
    echo "   Backing up running OpenClaw may cause data inconsistency"
    echo "   Recommended to stop service first: openclaw gateway stop"
    echo ""
    if [ "$AUTO_YES" = true ]; then
        echo "⚠️  Auto-confirmed (--yes), continuing backup..."
    else
        read -p "Continue backup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Backup cancelled"
            exit 0
        fi
    fi
    echo "⚠️  Continuing backup (may have risks)..."
    echo ""
fi

# Create temporaryBackup directory
mkdir -p "$BACKUP_DIR"

# 备份核心Config file
echo "📋 Backing up core config..."
if [ "$JSON_PARSER" = "jq" ]; then
    CORE_FILES=$(jq -r '.backup.include.core_config[]' "$CONFIG_FILE")
else
    CORE_FILES=$(python3 -c "import json; data=json.load(open('$CONFIG_FILE')); print('\n'.join(data['backup']['include']['core_config']))")
fi

while IFS= read -r file; do
    if [ -f "$OPENCLAW_DIR/$file" ]; then
        cp "$OPENCLAW_DIR/$file" "$BACKUP_DIR/"
        echo "   ✓ $file"
    elif [ "$VERBOSE" = true ]; then
        echo "   ⊘ $file (not found)"
    fi
done <<< "$CORE_FILES"

# 自动Found并备份工作空间
if [ "$AUTO_DISCOVER" = "true" ]; then
    echo "📁 Auto-discovering workspaces..."
    WORKSPACES=$(find "$OPENCLAW_DIR" -maxdepth 1 -type d -name "$WORKSPACE_PATTERN" -exec basename {} \;)

    if [ -n "$WORKSPACES" ]; then
        while IFS= read -r workspace; do
            if [ -d "$OPENCLAW_DIR/$workspace" ]; then
                cp -r "$OPENCLAW_DIR/$workspace" "$BACKUP_DIR/"
                echo "   ✓ $workspace"
            fi
        done <<< "$WORKSPACES"
    else
        echo "   ⚠️  No matches found for '$WORKSPACE_PATTERN' workspaces"
    fi
fi

# Backing up shared resources
if [ "$INCLUDE_SHARED" = "true" ] && [ -d "$OPENCLAW_DIR/shared" ]; then
    echo "🤝 Backing up shared resources..."
    cp -r "$OPENCLAW_DIR/shared" "$BACKUP_DIR/"
    echo "   ✓ shared"
fi

# Backing up agents config
if [ "$INCLUDE_AGENTS" = "true" ] && [ -d "$OPENCLAW_DIR/agents" ]; then
    echo "🤖 Backing up agents config..."
    cp -r "$OPENCLAW_DIR/agents" "$BACKUP_DIR/"
    echo "   ✓ agents"
fi

# Backing up credentials
if [ "$INCLUDE_CREDENTIALS" = "true" ] && [ -d "$OPENCLAW_DIR/credentials" ]; then
    echo "🔐 Backing up credentials..."
    cp -r "$OPENCLAW_DIR/credentials" "$BACKUP_DIR/"
    echo "   ✓ credentials"
fi

# Backing up memory
if [ "$INCLUDE_MEMORY" = "true" ] && [ -d "$OPENCLAW_DIR/memory" ]; then
    echo "🧠 Backing up memory..."
    cp -r "$OPENCLAW_DIR/memory" "$BACKUP_DIR/"
    echo "   ✓ memory"
fi

# 处理路径占位符
if [ "$PATH_PLACEHOLDER_ENABLED" = "true" ]; then
    echo "🔧 Processing path portability..."

    if [ -f "$BACKUP_DIR/openclaw.json" ]; then
        # 替换各种可能\ 路径格式
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|$HOME/.openclaw|{{OPENCLAW_DIR}}|g" "$BACKUP_DIR/openclaw.json"
            sed -i '' "s|/root/.openclaw|{{OPENCLAW_DIR}}|g" "$BACKUP_DIR/openclaw.json"
            sed -i '' "s|$HOME|{{HOME}}|g" "$BACKUP_DIR/openclaw.json"
        else
            sed -i "s|$HOME/.openclaw|{{OPENCLAW_DIR}}|g" "$BACKUP_DIR/openclaw.json"
            sed -i "s|/root/.openclaw|{{OPENCLAW_DIR}}|g" "$BACKUP_DIR/openclaw.json"
            sed -i "s|$HOME|{{HOME}}|g" "$BACKUP_DIR/openclaw.json"
        fi
        echo "   ✓ Path placeholders applied"
    fi
fi

# Cleaning up excluded files
echo "🧹 Cleaning up excluded files..."
if [ "$JSON_PARSER" = "jq" ]; then
    EXCLUDE_PATTERNS=$(jq -r '.backup.exclude_patterns[]' "$CONFIG_FILE" 2>/dev/null || echo "")
else
    EXCLUDE_PATTERNS=$(python3 -c "import json; data=json.load(open('$CONFIG_FILE')); print('\n'.join(data['backup'].get('exclude_patterns', [])))" 2>/dev/null || echo "")
fi

if [ -n "$EXCLUDE_PATTERNS" ]; then
    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            find "$BACKUP_DIR" -name "$pattern" -delete 2>/dev/null || true
            [ "$VERBOSE" = true ] && echo "   ⊘ deleted: $pattern"
        fi
    done <<< "$EXCLUDE_PATTERNS"
fi

# Create备份元数据
echo "📝 Generating backup metadata..."
cat > "$BACKUP_DIR/BACKUP_INFO.txt" << EOF
Backup Name: $BACKUP_NAME
Backup Date: $(date)
Backup From: $(hostname)
OpenClaw Version: $(openclaw --version 2>/dev/null || echo "unknown")
Backup Script Version: 1.0.0
OS: $OSTYPE
Config File: $CONFIG_FILE
Auto Discover: $AUTO_DISCOVER
Include Shared: $INCLUDE_SHARED
Include Agents: $INCLUDE_AGENTS
Include Credentials: $INCLUDE_CREDENTIALS
Include Memory: $INCLUDE_MEMORY
Path Placeholders: $PATH_PLACEHOLDER_ENABLED
EOF

# 打包
echo "📦 Packing backup file..."
cd /tmp
tar -czf "$ARCHIVE_NAME" "openclaw-backup-$BACKUP_NAME" 2>/dev/null

# Create备份存储目录
BACKUPS_DIR="$OPENCLAW_DIR/backups"
mkdir -p "$BACKUPS_DIR"

# Move toBackup directory
OUTPUT_PATH="$BACKUPS_DIR/$ARCHIVE_NAME"
mv "$ARCHIVE_NAME" "$OUTPUT_PATH"
rm -rf "$BACKUP_DIR"

# Generating checksum
echo "🔐 Generating checksum..."
if command -v sha256sum &> /dev/null; then
    sha256sum "$OUTPUT_PATH" > "$OUTPUT_PATH.sha256"
    echo "   ✓ SHA256: $OUTPUT_PATH.sha256"
elif command -v shasum &> /dev/null; then
    shasum -a 256 "$OUTPUT_PATH" > "$OUTPUT_PATH.sha256"
    echo "   ✓ SHA256: $OUTPUT_PATH.sha256"
else
    echo "   ⚠️  sha256sum/shasum not found, skipping checksum generation"
fi

echo ""
echo "✅ Backup complete: $OUTPUT_PATH"

# ShowFile size
if command -v du &> /dev/null; then
    SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
    echo "   File size: $SIZE"
fi

# GitHub Release 提示
GITHUB_ENABLED=$(get_config '.github.enabled' 'false')
if [ "$GITHUB_ENABLED" = "true" ]; then
    GITHUB_REPO=$(get_config '.github.repo' '')
    RELEASE_PREFIX=$(get_config '.github.release_prefix' 'v')

    if [ -n "$GITHUB_REPO" ]; then
        echo ""
        echo "📤 Upload to GitHub Release:"
        echo "   gh release create ${RELEASE_PREFIX}${BACKUP_NAME} \\"
        echo "     --repo $GITHUB_REPO \\"
        echo "     --title \"Backup $BACKUP_NAME\" \\"
        echo "     --notes \"Automated backup from $(hostname) at $(date)\" \\"
        echo "     $OUTPUT_PATH"
    fi
fi

echo ""
echo "💡 Restore command:"
echo "   cd ~/.openclaw/openclaw-backup"
echo "   ./restore.sh $OUTPUT_PATH"
