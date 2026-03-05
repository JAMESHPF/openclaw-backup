#!/bin/bash
# OpenClaw 备份工具
# 支持配置文件驱动，自动发现工作空间，适配任何 OpenClaw 安装
# 用法: ./backup.sh [backup-name] [--config path/to/config.json]

set -e

# 默认配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
BACKUP_NAME=""
VERBOSE=false

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
        --help|-h)
            cat << EOF
OpenClaw 通用备份工具

用法: $0 [backup-name] [选项]

选项:
  --config FILE     指定配置文件 (默认: backup-config.json)
  --verbose, -v     显示详细输出
  --help, -h        显示此帮助信息

示例:
  $0                          # 使用默认配置和时间戳命名
  $0 my-backup                # 指定备份名称
  $0 --config custom.json     # 使用自定义配置
  $0 my-backup --verbose      # 显示详细信息

配置文件格式请参考 backup-config.json
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

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件不存在: $CONFIG_FILE"
    echo "请创建配置文件或使用 --config 指定路径"
    exit 1
fi

# 读取配置 (使用 jq 或 python)
if command -v jq &> /dev/null; then
    JSON_PARSER="jq"
elif command -v python3 &> /dev/null; then
    JSON_PARSER="python3"
else
    echo "❌ 需要 jq 或 python3 来解析配置文件"
    exit 1
fi

# 解析配置的辅助函数
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

# 读取配置
OPENCLAW_DIR=$(get_config '.openclaw_dir' "$HOME/.openclaw")
OPENCLAW_DIR="${OPENCLAW_DIR/#\~/$HOME}"  # 展开 ~
AUTO_DISCOVER=$(get_config '.backup.auto_discover_workspaces' 'true')
WORKSPACE_PATTERN=$(get_config '.backup.workspace_pattern' 'workspace*')
INCLUDE_SHARED=$(get_config '.backup.include.shared' 'true')
INCLUDE_AGENTS=$(get_config '.backup.include.agents' 'false')
INCLUDE_CREDENTIALS=$(get_config '.backup.include.credentials' 'false')
INCLUDE_MEMORY=$(get_config '.backup.include.memory' 'true')
PATH_PLACEHOLDER_ENABLED=$(get_config '.backup.path_placeholders.enabled' 'true')

# 设置备份名称
if [ -z "$BACKUP_NAME" ]; then
    BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
fi

BACKUP_DIR="/tmp/openclaw-backup-$BACKUP_NAME"
ARCHIVE_NAME="openclaw-$BACKUP_NAME.tar.gz"

echo "🔄 开始备份 OpenClaw 配置..."
[ "$VERBOSE" = true ] && echo "   配置文件: $CONFIG_FILE"
[ "$VERBOSE" = true ] && echo "   OpenClaw 目录: $OPENCLAW_DIR"

# 检查 OpenClaw 目录
if [ ! -d "$OPENCLAW_DIR" ]; then
    echo "❌ OpenClaw 目录不存在: $OPENCLAW_DIR"
    exit 1
fi

# 检查 OpenClaw 是否正在运行
if pgrep -f "openclaw" > /dev/null 2>&1; then
    echo ""
    echo "⚠️  检测到 OpenClaw 正在运行"
    echo "   备份运行中的 OpenClaw 可能导致数据不一致"
    echo "   建议先停止服务: openclaw gateway stop"
    echo ""
    read -p "是否继续备份? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 已取消备份"
        exit 0
    fi
    echo "⚠️  继续备份（可能存在风险）..."
    echo ""
fi

# 创建临时备份目录
mkdir -p "$BACKUP_DIR"

# 备份核心配置文件
echo "📋 备份核心配置..."
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
        echo "   ⊘ $file (不存在)"
    fi
done <<< "$CORE_FILES"

# 自动发现并备份工作空间
if [ "$AUTO_DISCOVER" = "true" ]; then
    echo "📁 自动发现工作空间..."
    WORKSPACES=$(find "$OPENCLAW_DIR" -maxdepth 1 -type d -name "$WORKSPACE_PATTERN" -exec basename {} \;)

    if [ -n "$WORKSPACES" ]; then
        while IFS= read -r workspace; do
            if [ -d "$OPENCLAW_DIR/$workspace" ]; then
                cp -r "$OPENCLAW_DIR/$workspace" "$BACKUP_DIR/"
                echo "   ✓ $workspace"
            fi
        done <<< "$WORKSPACES"
    else
        echo "   ⚠️  未发现匹配 '$WORKSPACE_PATTERN' 的工作空间"
    fi
fi

# 备份共享资源
if [ "$INCLUDE_SHARED" = "true" ] && [ -d "$OPENCLAW_DIR/shared" ]; then
    echo "🤝 备份共享资源..."
    cp -r "$OPENCLAW_DIR/shared" "$BACKUP_DIR/"
    echo "   ✓ shared"
fi

# 备份 agents 配置
if [ "$INCLUDE_AGENTS" = "true" ] && [ -d "$OPENCLAW_DIR/agents" ]; then
    echo "🤖 备份 agents 配置..."
    cp -r "$OPENCLAW_DIR/agents" "$BACKUP_DIR/"
    echo "   ✓ agents"
fi

# 备份 credentials
if [ "$INCLUDE_CREDENTIALS" = "true" ] && [ -d "$OPENCLAW_DIR/credentials" ]; then
    echo "🔐 备份 credentials..."
    cp -r "$OPENCLAW_DIR/credentials" "$BACKUP_DIR/"
    echo "   ✓ credentials"
fi

# 备份 memory
if [ "$INCLUDE_MEMORY" = "true" ] && [ -d "$OPENCLAW_DIR/memory" ]; then
    echo "🧠 备份 memory..."
    cp -r "$OPENCLAW_DIR/memory" "$BACKUP_DIR/"
    echo "   ✓ memory"
fi

# 处理路径占位符
if [ "$PATH_PLACEHOLDER_ENABLED" = "true" ]; then
    echo "🔧 处理路径可移植性..."

    if [ -f "$BACKUP_DIR/openclaw.json" ]; then
        # 替换各种可能的路径格式
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|$HOME/.openclaw|{{OPENCLAW_DIR}}|g" "$BACKUP_DIR/openclaw.json"
            sed -i '' "s|/root/.openclaw|{{OPENCLAW_DIR}}|g" "$BACKUP_DIR/openclaw.json"
            sed -i '' "s|$HOME|{{HOME}}|g" "$BACKUP_DIR/openclaw.json"
        else
            sed -i "s|$HOME/.openclaw|{{OPENCLAW_DIR}}|g" "$BACKUP_DIR/openclaw.json"
            sed -i "s|/root/.openclaw|{{OPENCLAW_DIR}}|g" "$BACKUP_DIR/openclaw.json"
            sed -i "s|$HOME|{{HOME}}|g" "$BACKUP_DIR/openclaw.json"
        fi
        echo "   ✓ 路径占位符已应用"
    fi
fi

# 清理排除的文件
echo "🧹 清理排除的文件..."
if [ "$JSON_PARSER" = "jq" ]; then
    EXCLUDE_PATTERNS=$(jq -r '.backup.exclude_patterns[]' "$CONFIG_FILE" 2>/dev/null || echo "")
else
    EXCLUDE_PATTERNS=$(python3 -c "import json; data=json.load(open('$CONFIG_FILE')); print('\n'.join(data['backup'].get('exclude_patterns', [])))" 2>/dev/null || echo "")
fi

if [ -n "$EXCLUDE_PATTERNS" ]; then
    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            find "$BACKUP_DIR" -name "$pattern" -delete 2>/dev/null || true
            [ "$VERBOSE" = true ] && echo "   ⊘ 已删除: $pattern"
        fi
    done <<< "$EXCLUDE_PATTERNS"
fi

# 创建备份元数据
echo "📝 生成备份元数据..."
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
echo "📦 打包备份文件..."
cd /tmp
tar -czf "$ARCHIVE_NAME" "openclaw-backup-$BACKUP_NAME" 2>/dev/null

# 创建备份存储目录
BACKUPS_DIR="$OPENCLAW_DIR/backups"
mkdir -p "$BACKUPS_DIR"

# 移动到备份目录
OUTPUT_PATH="$BACKUPS_DIR/$ARCHIVE_NAME"
mv "$ARCHIVE_NAME" "$OUTPUT_PATH"
rm -rf "$BACKUP_DIR"

# 生成校验和
echo "🔐 生成校验和..."
if command -v sha256sum &> /dev/null; then
    sha256sum "$OUTPUT_PATH" > "$OUTPUT_PATH.sha256"
    echo "   ✓ SHA256: $OUTPUT_PATH.sha256"
elif command -v shasum &> /dev/null; then
    shasum -a 256 "$OUTPUT_PATH" > "$OUTPUT_PATH.sha256"
    echo "   ✓ SHA256: $OUTPUT_PATH.sha256"
else
    echo "   ⚠️  未找到 sha256sum/shasum，跳过校验和生成"
fi

echo ""
echo "✅ 备份完成: $OUTPUT_PATH"

# 显示文件大小
if command -v du &> /dev/null; then
    SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
    echo "   文件大小: $SIZE"
fi

# GitHub Release 提示
GITHUB_ENABLED=$(get_config '.github.enabled' 'false')
if [ "$GITHUB_ENABLED" = "true" ]; then
    GITHUB_REPO=$(get_config '.github.repo' '')
    RELEASE_PREFIX=$(get_config '.github.release_prefix' 'v')

    if [ -n "$GITHUB_REPO" ]; then
        echo ""
        echo "📤 上传到 GitHub Release:"
        echo "   gh release create ${RELEASE_PREFIX}${BACKUP_NAME} \\"
        echo "     --repo $GITHUB_REPO \\"
        echo "     --title \"Backup $BACKUP_NAME\" \\"
        echo "     --notes \"Automated backup from $(hostname) at $(date)\" \\"
        echo "     $OUTPUT_PATH"
    fi
fi

echo ""
echo "💡 恢复命令:"
echo "   cd ~/.openclaw/openclaw-backup"
echo "   ./restore.sh $OUTPUT_PATH"
