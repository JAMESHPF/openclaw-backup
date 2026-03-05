#!/bin/bash
# OpenClaw Backup Tool - 安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/JAMESHPF/openclaw-backup/main/install.sh | bash

set -e

INSTALL_DIR="$HOME/.openclaw/openclaw-backup"
REPO_URL="https://github.com/JAMESHPF/openclaw-backup.git"

echo "🚀 OpenClaw 备份工具安装程序"
echo ""

# 检查 OpenClaw 是否安装
if [ ! -d "$HOME/.openclaw" ]; then
    echo "❌ 错误: 未找到 OpenClaw 安装"
    echo "   请先安装 OpenClaw: https://openclaw.ai"
    exit 1
fi

echo "✅ 检测到 OpenClaw 安装"

# 检查依赖
echo ""
echo "🔍 检查依赖..."

HAS_JQ=false
HAS_PYTHON=false

if command -v jq &> /dev/null; then
    HAS_JQ=true
    echo "   ✓ jq 已安装"
fi

if command -v python3 &> /dev/null; then
    HAS_PYTHON=true
    echo "   ✓ python3 已安装"
fi

if [ "$HAS_JQ" = false ] && [ "$HAS_PYTHON" = false ]; then
    echo ""
    echo "❌ 错误: 需要 jq 或 python3 来解析配置文件"
    echo ""
    echo "安装方法:"
    echo "  macOS:   brew install jq"
    echo "  Ubuntu:  sudo apt install jq"
    echo "  或使用系统自带的 python3"
    exit 1
fi

# 检查 git
if ! command -v git &> /dev/null; then
    echo "❌ 错误: 需要 git"
    exit 1
fi

echo "   ✓ git 已安装"

# 安装
echo ""
echo "📦 开始安装..."

if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  目录已存在: $INSTALL_DIR"
    read -p "是否覆盖安装? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 已取消安装"
        exit 0
    fi
    rm -rf "$INSTALL_DIR"
fi

# 克隆仓库
git clone --quiet "$REPO_URL" "$INSTALL_DIR"

# 设置执行权限
chmod +x "$INSTALL_DIR"/*.sh

echo ""
echo "✅ 安装完成！"
echo ""
echo "📖 快速开始:"
echo "   cd ~/.openclaw/openclaw-backup"
echo "   ./backup.sh"
echo ""
echo "📚 查看文档:"
echo "   cat ~/.openclaw/openclaw-backup/README.md"
echo "   cat ~/.openclaw/openclaw-backup/QUICKSTART.md"
echo ""
echo "⚠️  安全提示:"
echo "   - 默认备份排除敏感信息（API 密钥等）"
echo "   - 完整备份请使用: ./backup.sh --config config-full.json"
echo "   - 详细安全说明请查看 README.md"
echo ""
