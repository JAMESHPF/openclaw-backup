# OpenClaw 备份工具

OpenClaw 配置的完整备份与恢复方案。

[English](README.md) | 简体中文

## 安装

```bash
# 一键安装
curl -fsSL https://raw.githubusercontent.com/JAMESHPF/openclaw-backup/main/install.sh | bash

# 手动安装
git clone https://github.com/JAMESHPF/openclaw-backup.git ~/.openclaw/openclaw-backup
cd ~/.openclaw/openclaw-backup && chmod +x *.sh
```

**依赖：** OpenClaw、jq 或 python3、git

**平台：** macOS / Linux。只要能跑 OpenClaw 的地方就能用 — 本地 Mac、VPS（Ubuntu/Debian/CentOS）、WSL2。

## 快速开始

```bash
cd ~/.openclaw/openclaw-backup

./backup.sh                    # 标准备份（安全）
./backup.sh my-backup          # 自定义备份名称
./backup.sh --verbose          # 详细输出

./restore.sh <backup.tar.gz>   # 从备份恢复
./restore.sh <file> --dry-run  # 仅预览

./cleanup.sh                   # 保留最近 10 个备份
./cleanup.sh --keep 5          # 保留最近 5 个
```

备份文件保存在 `~/.openclaw/backups/`。

## 备份模式

本工具提供两种模式，兼顾安全与完整性：

| | ✅ 标准模式（默认） | ⚠️ 完整模式 |
|---|---|---|
| **命令** | `./backup.sh` | `./backup.sh --config config-full.json` |
| **适用场景** | 日常备份、配置分享 | 机器迁移、灾难恢复 |
| 📋 openclaw.json | ✅ 包含 | ✅ 包含 |
| 📁 工作空间 | ✅ 包含 | ✅ 包含 |
| 🤝 共享资源 | ✅ 包含 | ✅ 包含 |
| 🧠 记忆数据 | ✅ 包含 | ✅ 包含 |
| 🔑 .env（API 密钥） | ❌ 排除 | ⚠️ 包含 |
| 🔐 auth-profiles.json | ❌ 排除 | ⚠️ 包含 |
| 🔐 credentials/ | ❌ 排除 | ⚠️ 包含 |
| 🤖 agents/ | ❌ 排除 | ⚠️ 包含 |
| **上传 GitHub？** | ✅ 安全 | ❌ 危险 - 包含密钥 |

> **原则：** 除机器迁移外一律使用标准模式。完整备份用完立即删除。

## 配置

编辑 `config.json` 自定义备份内容：

```json
{
  "openclaw_dir": "~/.openclaw",
  "backup": {
    "auto_discover_workspaces": true,
    "workspace_pattern": "workspace*",
    "include": {
      "core_config": ["openclaw.json"],
      "shared": true,
      "agents": false,
      "credentials": false,
      "memory": true
    }
  }
}
```

`config-full.json` 与之相同，但所有 include 项均为 `true`，且 `core_config` 中额外包含 `.env` 和 `auth-profiles.json`。

## 路径可移植

备份时自动将绝对路径替换为占位符（`{{HOME}}`、`{{OPENCLAW_DIR}}`），恢复时自动还原。支持 VPS 与本地、不同用户目录之间无缝迁移，无需手动修改路径。

## GitHub 集成

将标准备份上传到 GitHub Releases 做异地存储：

```bash
# 上传
gh release create v$(date +%Y%m%d) \
  --repo username/openclaw-workspace \
  --title "Backup $(date +%Y-%m-%d)" \
  ~/.openclaw/backups/openclaw-backup-*.tar.gz

# 下载并恢复
gh release download v20260305 --repo username/openclaw-workspace
./restore.sh openclaw-backup-20260305.tar.gz
openclaw gateway restart
```

## 迁移流程

```bash
# 1. 在旧机器上完整备份
./backup.sh --config config-full.json migration

# 2. 安全传输
scp ~/.openclaw/backups/openclaw-migration.tar.gz new-machine:~/

# 3. 在新机器上恢复
cd ~/.openclaw/openclaw-backup
./restore.sh ~/openclaw-migration.tar.gz
openclaw gateway restart

# 4. 删除备份文件
rm ~/openclaw-migration.tar.gz
```

## 安全

### 上传前检查

```bash
# 确认备份中不含敏感文件
tar -tzf <backup.tar.gz> | grep -E "(\.env|auth-profiles|credentials)"
# 无输出则可安全上传
```

### 加密完整备份（可选）

```bash
gpg --encrypt --recipient your@email.com backup.tar.gz
rm backup.tar.gz  # 删除未加密的原文件
```

### 凭据泄露应急

1. **立即撤销 API 密钥** - [Claude](https://console.anthropic.com/settings/keys)、[OpenAI](https://platform.openai.com/api-keys) 及其他服务
2. **删除泄露文件**，清除 Git 历史记录
3. **重新生成所有凭据**，更新 `.env`
4. **监控账户活动**，检查是否有未授权使用

## 文件说明

| 文件 | 说明 |
|------|------|
| `backup.sh` | 备份脚本，支持自动发现工作空间和校验和生成 |
| `restore.sh` | 恢复脚本，支持完整性验证、路径自动修复、恢复前安全备份 |
| `cleanup.sh` | 清理旧备份，保留最近 N 个 |
| `config.json` | 标准模式配置 - 排除敏感文件 |
| `config-full.json` | 完整模式配置 - 包含所有文件 |
| `install.sh` | 一键安装脚本，含依赖检查 |

## 版本

v1.1.0 - 2026-03-05

## 许可证

MIT
