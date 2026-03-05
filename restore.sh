#!/bin/bash
# OpenClaw 恢复工具
# 支持配置文件驱动，自动路径修复，适配任何环境
# 用法: ./restore.sh <backup-file.tar.gz> [--config path/to/config.json]

set -e

# 默认配置
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
OpenClaw 通用恢复工具

用法: $0 <backup-file.tar.gz> [选项]

选项:
  --config FILE     指定配置文件 (默认: backup-config.json)
  --verbose, -v     显示详细输出
  --dry-run         预览恢复操作，不实际执行
  --help, -h        显示此帮助信息

示例:
  $0 openclaw-backup-20260305.tar.gz
  $0 backup.tar.gz --config custom.json
  $0 backup.tar.gz --dry-run --verbose

配置文件格式请参考 backup-config.json
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

# 检查备份文件
if [ -z "$BACKUP_FILE" ]; then
    echo "❌ 请指定备份文件"
    echo "用法: $0 <backup-file.tar.gz>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  配置文件不存在: $CONFIG_FILE"
    echo "使用默认配置..."
    OPENCLAW_DIR="$HOME/.openclaw"
    BACKUP_EXISTING=true
    AUTO_FIX_PATHS=true
else
    # 读取配置
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

    OPENCLAW_DIR=$(get_config '.openclaw_dir' "$HOME/.openclaw")
    OPENCLAW_DIR="${OPENCLAW_DIR/#\~/$HOME}"
    BACKUP_EXISTING=$(get_config '.restore.backup_existing' 'true')
    AUTO_FIX_PATHS=$(get_config '.restore.auto_fix_paths' 'true')
fi

TEMP_DIR="/tmp/openclaw-restore-$$"

echo "🔄 开始恢复 OpenClaw 配置..."
[ "$VERBOSE" = true ] && echo "   备份文件: $BACKUP_FILE"
[ "$VERBOSE" = true ] && echo "   目标目录: $OPENCLAW_DIR"
[ "$VERBOSE" = true ] && echo "   配置文件: $CONFIG_FILE"
[ "$DRY_RUN" = true ] && echo "   ⚠️  预览模式 (不会实际修改文件)"

# 备份现有配置
if [ "$BACKUP_EXISTING" = "true" ] && [ -d "$OPENCLAW_DIR" ] && [ "$DRY_RUN" = false ]; then
    BACKUP_OLD="$OPENCLAW_DIR.before-restore-$(date +%Y%m%d-%H%M%S)"
    echo "💾 备份现有配置到 $BACKUP_OLD..."
    mv "$OPENCLAW_DIR" "$BACKUP_OLD"
    echo "   ✓ 现有配置已备份"
fi

# 解压备份
echo "📦 解压备份文件..."
mkdir -p "$TEMP_DIR"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# 查找备份目录
BACKUP_CONTENT=$(find "$TEMP_DIR" -type d -name "openclaw-backup-*" | head -1)

if [ -z "$BACKUP_CONTENT" ]; then
    echo "❌ 备份文件格式错误"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 显示备份信息
if [ -f "$BACKUP_CONTENT/BACKUP_INFO.txt" ]; then
    echo ""
    echo "📋 备份信息:"
    cat "$BACKUP_CONTENT/BACKUP_INFO.txt"
    echo ""
fi

# 预览模式：显示将要恢复的文件
if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "📁 将要恢复的文件:"
    find "$BACKUP_CONTENT" -type f -o -type d | sed "s|$BACKUP_CONTENT|  |" | head -50
    echo ""
    echo "💡 使用不带 --dry-run 参数来实际执行恢复"
    rm -rf "$TEMP_DIR"
    exit 0
fi

# 创建目标目录
mkdir -p "$OPENCLAW_DIR"

# 恢复文件
echo "📁 恢复文件..."
cp -r "$BACKUP_CONTENT"/* "$OPENCLAW_DIR/"
echo "   ✓ 文件已恢复"

# 自动修复路径
if [ "$AUTO_FIX_PATHS" = "true" ] && [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
    echo "🔧 自动修复路径..."

    # 替换占位符为实际路径
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|{{OPENCLAW_DIR}}|$OPENCLAW_DIR|g" "$OPENCLAW_DIR/openclaw.json"
        sed -i '' "s|{{HOME}}|$HOME|g" "$OPENCLAW_DIR/openclaw.json"
    else
        sed -i "s|{{OPENCLAW_DIR}}|$OPENCLAW_DIR|g" "$OPENCLAW_DIR/openclaw.json"
        sed -i "s|{{HOME}}|$HOME|g" "$OPENCLAW_DIR/openclaw.json"
    fi

    echo "   ✓ 路径已修复"

    # 验证路径修复
    if grep -q "{{OPENCLAW_DIR}}" "$OPENCLAW_DIR/openclaw.json" 2>/dev/null; then
        echo "   ⚠️  警告: 仍有未替换的占位符"
    fi

    if grep -q "/root/.openclaw" "$OPENCLAW_DIR/openclaw.json" 2>/dev/null; then
        echo "   ⚠️  警告: 检测到 /root 路径，可能需要手动修复"
    fi
fi

# 清理
rm -rf "$TEMP_DIR"

echo ""
echo "✅ 恢复完成！"
echo ""
echo "🔄 下一步操作:"
echo "   1. 重启 OpenClaw Gateway:"
echo "      openclaw gateway restart"
echo ""
echo "   2. 检查状态:"
echo "      openclaw status"
echo ""
echo "   3. 如需重新配对 Telegram Bot:"
echo "      - 向每个 bot 发送 /start"
echo "      - 获取 pairing code"
echo "      - 执行: openclaw pairing approve telegram <code>"
echo ""

# 验证关键文件
echo "🔍 验证关键文件:"
CRITICAL_FILES=("openclaw.json" ".env")
ALL_OK=true

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$OPENCLAW_DIR/$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file (缺失)"
        ALL_OK=false
    fi
done

if [ "$ALL_OK" = false ]; then
    echo ""
    echo "⚠️  警告: 部分关键文件缺失，请检查备份完整性"
fi
