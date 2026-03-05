#!/bin/bash
# OpenClaw 备份清理工具
# 用于清理旧的备份文件，保留最近的 N 个备份
# 用法: ./cleanup.sh [--keep N]

set -e

OPENCLAW_DIR="$HOME/.openclaw"
BACKUPS_DIR="$OPENCLAW_DIR/backups"
KEEP_COUNT=10  # 默认保留最近 10 个备份

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep)
            KEEP_COUNT="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
OpenClaw 备份清理工具

用法: $0 [选项]

选项:
  --keep N          保留最近 N 个备份 (默认: 10)
  --help, -h        显示此帮助信息

示例:
  $0                # 保留最近 10 个备份
  $0 --keep 5       # 保留最近 5 个备份
  $0 --keep 20      # 保留最近 20 个备份

备份目录: $BACKUPS_DIR
EOF
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 检查备份目录
if [ ! -d "$BACKUPS_DIR" ]; then
    echo "📁 备份目录不存在: $BACKUPS_DIR"
    echo "   没有需要清理的备份"
    exit 0
fi

# 统计备份文件数量
BACKUP_COUNT=$(find "$BACKUPS_DIR" -name "openclaw-backup-*.tar.gz" -type f | wc -l | tr -d ' ')

if [ "$BACKUP_COUNT" -eq 0 ]; then
    echo "📁 备份目录为空，没有需要清理的备份"
    exit 0
fi

echo "🔍 发现 $BACKUP_COUNT 个备份文件"
echo "📋 保留最近 $KEEP_COUNT 个备份"

if [ "$BACKUP_COUNT" -le "$KEEP_COUNT" ]; then
    echo "✅ 备份数量未超过限制，无需清理"
    exit 0
fi

# 计算需要删除的数量
DELETE_COUNT=$((BACKUP_COUNT - KEEP_COUNT))
echo "🗑️  将删除 $DELETE_COUNT 个旧备份"
echo ""

# 列出将要删除的文件
echo "将要删除的备份:"
find "$BACKUPS_DIR" -name "openclaw-backup-*.tar.gz" -type f -print0 | \
    xargs -0 ls -t | \
    tail -n "$DELETE_COUNT" | \
    while read -r file; do
        SIZE=$(du -h "$file" | cut -f1)
        echo "  - $(basename "$file") ($SIZE)"
    done

echo ""
read -p "确认删除这些备份? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消"
    exit 0
fi

# 删除旧备份
echo "🗑️  开始删除..."
DELETED=0

# 使用数组存储要删除的文件
mapfile -t FILES_TO_DELETE < <(find "$BACKUPS_DIR" -name "openclaw-backup-*.tar.gz" -type f -print0 | xargs -0 ls -t | tail -n "$DELETE_COUNT")

for file in "${FILES_TO_DELETE[@]}"; do
    if [ -f "$file" ]; then
        # 同时删除校验和文件
        rm -f "$file" "${file}.sha256"
        echo "  ✓ 已删除: $(basename "$file")"
        DELETED=$((DELETED + 1))
    fi
done

echo ""
echo "✅ 清理完成，已删除 $DELETE_COUNT 个旧备份"
echo "📁 当前保留 $KEEP_COUNT 个备份"
