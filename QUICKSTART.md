# OpenClaw 通用备份工具 - 快速开始

## 一分钟上手

### 1. 备份

```bash
cd ~/.openclaw
./backup-universal.sh
```

输出示例：
```
🔄 开始备份 OpenClaw 配置...
📋 备份核心配置...
   ✓ openclaw.json
   ✓ .env
📁 自动发现工作空间...
   ✓ workspace
   ✓ workspace-dev
   ✓ workspace-atlas
   ✓ workspace-content
🤝 备份共享资源...
   ✓ shared
🧠 备份 memory...
   ✓ memory
✅ 备份完成: ~/openclaw-backup-20260305-212504.tar.gz
   文件大小: 7.8M
```

### 2. 恢复

```bash
cd ~/.openclaw
./restore-universal.sh ~/openclaw-backup-20260305-212504.tar.gz
openclaw gateway restart
```

## 常用命令

### 指定备份名称
```bash
./backup-universal.sh my-backup-name
```

### 查看帮助
```bash
./backup-universal.sh --help
./restore-universal.sh --help
```

### 预览恢复（不实际修改）
```bash
./restore-universal.sh backup.tar.gz --dry-run
```

### 显示详细信息
```bash
./backup-universal.sh --verbose
./restore-universal.sh backup.tar.gz --verbose
```

## 配置文件位置

`~/.openclaw/backup-config.json`

## 完整文档

查看 `README-universal.md` 了解：
- 配置文件详解
- 使用场景
- 故障排查
- 高级用法

## 核心优势

✅ **自动发现** - 无需手动列出 agent 名称
✅ **路径可移植** - VPS ↔ 本地无缝迁移
✅ **配置驱动** - 灵活的备份策略
✅ **安全可靠** - 恢复前自动备份现有配置
✅ **预览模式** - 查看将要恢复的内容

## 快速配置

编辑 `backup-config.json`：

```json
{
  "openclaw_dir": "~/.openclaw",
  "backup": {
    "include": {
      "shared": true,      // 共享资源
      "agents": false,     // agents 配置
      "credentials": false, // 凭证（敏感）
      "memory": true       // 记忆数据
    }
  }
}
```

## 上传到 GitHub

```bash
gh release create v20260305 \
  --repo username/openclaw-workspace \
  --title "Backup 2026-03-05" \
  ~/openclaw-backup-20260305.tar.gz
```

## 从 GitHub 恢复

```bash
gh release download v20260305 --repo username/openclaw-workspace
./restore-universal.sh openclaw-backup-20260305.tar.gz
openclaw gateway restart
```

## 需要帮助？

1. 查看 `README-universal.md` 完整文档
2. 运行 `--help` 查看命令选项
3. 使用 `--dry-run` 预览操作
