#!/bin/bash
# OpenClaw Backup Tool - Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/JAMESHPF/openclaw-backup/main/install.sh | bash

set -e

INSTALL_DIR="$HOME/.openclaw/openclaw-backup"
REPO_URL="https://github.com/JAMESHPF/openclaw-backup.git"

echo "🚀 OpenClaw Backup Tool Installer"
echo ""

# Check if OpenClaw is installed
if [ ! -d "$HOME/.openclaw" ]; then
    echo "❌ Error: OpenClaw installation not found"
    echo "   Please install OpenClaw first: https://openclaw.ai"
    exit 1
fi

echo "✅ OpenClaw installation detected"

# Check dependencies
echo ""
echo "🔍 Checking dependencies..."

HAS_JQ=false
HAS_PYTHON=false

if command -v jq &> /dev/null; then
    HAS_JQ=true
    echo "   ✓ jq installed"
fi

if command -v python3 &> /dev/null; then
    HAS_PYTHON=true
    echo "   ✓ python3 installed"
fi

if [ "$HAS_JQ" = false ] && [ "$HAS_PYTHON" = false ]; then
    echo ""
    echo "❌ Error: jq or python3 required for config parsing"
    echo ""
    echo "Installation:"
    echo "  macOS:   brew install jq"
    echo "  Ubuntu:  sudo apt install jq"
    echo "  Or use system python3"
    exit 1
fi

# Check git
if ! command -v git &> /dev/null; then
    echo "❌ Error: git required"
    exit 1
fi

echo "   ✓ git installed"

# Install
echo ""
echo "📦 Starting installation..."

if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  Directory already exists: $INSTALL_DIR"
    read -p "Overwrite installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
    rm -rf "$INSTALL_DIR"
fi

# Clone repository
git clone --quiet "$REPO_URL" "$INSTALL_DIR"

# Set execute permissions
chmod +x "$INSTALL_DIR"/*.sh

echo ""
echo "✅ Installation complete!"
echo ""
echo "📖 Quick start:"
echo "   cd ~/.openclaw/openclaw-backup"
echo "   ./backup.sh"
echo ""
echo "📚 View documentation:"
echo "   cat ~/.openclaw/openclaw-backup/README.md"
echo "   cat ~/.openclaw/openclaw-backup/QUICKSTART.md"
echo ""
echo "⚠️  Security notice:"
echo "   - Default backup excludes sensitive data (API keys, etc.)"
echo "   - For full backup use: ./backup.sh --config config-full.json"
echo "   - See README.md for detailed security guidelines"
echo ""
