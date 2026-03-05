# OpenClaw 备份工具

OpenClaw 配置的完整备份与恢复解决方案。

[English](README.md) | 简体中文

## 📦 安装

### 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/JAMESHPF/openclaw-backup/main/install.sh | bash
```

### 手动安装

```bash
git clone https://github.com/JAMESHPF/openclaw-backup.git ~/.openclaw/openclaw-backup
cd ~/.openclaw/openclaw-backup
chmod +x *.sh
```

### 依赖要求

- OpenClaw（必需）
- jq 或 python3（必需，用于解析配置）
- git（必需，用于安装）

## ⚠️ 重要安全提示

**OpenClaw 配置包含敏感信息，请谨慎处理备份文件！**

### 敏感信息清单

**🔴 高度敏感（绝不公开分享）**：
- `.env` - API 密钥（Claude、OpenAI、Tavily、Brave 等）
- `auth-profiles.json` - OAuth 令牌和认证凭据
- `credentials/` - 服务凭据
- `openclaw.json` 中的 Telegram bot token

**风险**：泄露可能导致账户被盗、产生未授权费用、服务滥用

**🟡 中度敏感（谨慎分享）**：
- `memory/*.sqlite` - 完整对话历史
- `workspace/memory/*.md` - 每日工作日志和项目讨论

**风险**：隐私泄露、工作信息暴露

### 两种备份模式

**标准模式（默认）- 安全** ✅
- 排除所有敏感文件（.env、auth-profiles.json、credentials/）
- 可安全上传到 GitHub（公开或私有仓库）
- 适合日常备份和配置分享

**完整模式 - 包含敏感数据** ⚠️
- 包含所有文件，包括 API 密钥和凭据
- **绝不上传到公开仓库！**
- 仅用于机器迁移和灾难恢复
- 使用后立即删除

## 快速开始

```bash
cd ~/.openclaw/openclaw-backup

# 标准备份（安全，排除敏感信息）
./backup.sh

# 完整备份（包含 API 密钥和敏感数据）
./backup.sh --config config-full.json full-backup

# 恢复
./restore.sh ~/.openclaw/backups/openclaw-backup-xxx.tar.gz

# 设置自动备份（推荐）
./setup-auto-backup.sh
```

## 功能特性

✅ **自动发现** - 自动查找所有工作空间，无需手动配置
✅ **路径可移植** - 支持 VPS ↔ 本地无缝迁移
✅ **配置驱动** - 通过 config.json 灵活控制备份内容
✅ **安全可靠** - 恢复前自动备份现有配置
✅ **预览模式** - 使用 --dry-run 预览恢复内容
✅ **双备份模式** - 标准模式保安全，完整模式做迁移
✅ **自动备份** - 定时每日/每周备份，支持 Telegram 通知
✅ **GitHub 集成** - 自动上传备份到私有仓库

## 文件说明

- `backup.sh` - 备份脚本
- `restore.sh` - 恢复脚本
- `cleanup.sh` - 清理旧备份
- `auto-backup.sh` - 自动备份（含通知）
- `setup-auto-backup.sh` - 设置自动备份
- `config.json` - 标准配置（排除敏感文件）⭐
- `config-full.json` - 完整配置（包含敏感文件）⚠️
- `QUICKSTART.md` - 快速参考卡片

## 备份存储

备份文件自动保存到：
```
~/.openclaw/backups/
├── openclaw-backup-20260305-212504.tar.gz
├── openclaw-backup-20260304-183022.tar.gz
└── ...
```

### 清理旧备份
```bash
# 保留最近 10 个备份（默认）
./cleanup.sh

# 保留最近 5 个备份
./cleanup.sh --keep 5
```

## 常用命令

### 备份
```bash
# 标准备份（默认）
./backup.sh

# 指定名称
./backup.sh my-backup

# 完整备份（包含敏感数据）
./backup.sh --config config-full.json migration

# 详细输出
./backup.sh --verbose

# 显示帮助
./backup.sh --help
```

### 恢复
```bash
# 基本恢复
./restore.sh ~/.openclaw/backups/openclaw-backup-xxx.tar.gz

# 预览模式（不实际修改）
./restore.sh backup.tar.gz --dry-run

# 详细输出
./restore.sh backup.tar.gz --verbose
```

## 备份内容对比

| 项目 | 标准模式 | 完整模式 |
|------|---------|---------|
| openclaw.json | ✅ | ✅ |
| .env（API 密钥）| ❌ | ⚠️ |
| auth-profiles.json | ❌ | ⚠️ |
| credentials/ | ❌ | ⚠️ |
| 工作空间 | ✅ | ✅ |
| 共享资源 | ✅ | ✅ |
| 记忆数据 | ✅ | ✅ |
| agents/ | ❌ | ⚠️ |
| **GitHub 公开** | ✅ 安全 | ❌ 危险 |
| **GitHub 私有** | ✅ 安全 | ⚠️ 谨慎 |

## 安全最佳实践

### 1. 日常备份使用标准模式
```bash
./backup.sh daily-$(date +%Y%m%d)
```

### 2. 仅在迁移时使用完整备份
```bash
# 迁移前
./backup.sh --config config-full.json migration

# 迁移后立即删除
rm ~/.openclaw/backups/openclaw-migration.tar.gz
```

### 3. 上传到 GitHub 前检查
```bash
# 检查备份是否包含敏感文件
tar -tzf ~/.openclaw/backups/openclaw-backup-xxx.tar.gz | grep -E "(\.env|auth-profiles|credentials)"

# 如果有输出，绝不上传！
```

### 4. 加密完整备份（可选）
```bash
# 加密
gpg --encrypt --recipient your@email.com \
  ~/.openclaw/backups/openclaw-full-backup.tar.gz

# 删除未加密的原文件
rm ~/.openclaw/backups/openclaw-full-backup.tar.gz
```

## GitHub 集成

### 上传标准备份（安全）
```bash
gh release create v20260305 \
  --repo username/openclaw-workspace \
  --title "Backup 2026-03-05" \
  ~/.openclaw/backups/openclaw-backup-20260305.tar.gz
```

### 下载并恢复
```bash
gh release download v20260305 --repo username/openclaw-workspace
./restore.sh openclaw-backup-20260305.tar.gz
openclaw gateway restart
```

## 数据泄露应急响应

如果不小心泄露了包含敏感信息的备份：

1. **立即撤销 API 密钥**
   - Claude API: https://console.anthropic.com/settings/keys
   - OpenAI: https://platform.openai.com/api-keys
   - 其他服务：各自的控制面板

2. **删除泄露的文件**
   - 从 GitHub 删除（如果已上传）
   - 清除 Git 历史（如果已提交）

3. **重新生成凭据**
   - 生成新的 API 密钥
   - 更新 `.env` 文件
   - 重新配置 Telegram bot

4. **检查账户活动**
   - 查看 API 使用日志
   - 检查异常调用
   - 监控账单变化

## 推荐工作流

### 自动备份（推荐）

设置自动每日/每周备份，支持通知：

```bash
# 运行设置向导
./setup-auto-backup.sh

# 向导会引导你完成：
# 1. 备份计划（每天/每周/自定义）
# 2. GitHub 上传（可选）
# 3. Telegram 通知（可选）
# 4. 备份保留策略

# 测试自动备份
./auto-backup.sh

# 查看日志
tail -f ~/.openclaw/logs/auto-backup.log

# 禁用自动备份
./setup-auto-backup.sh --disable
```

**功能特性**：
- 通过 cron 定时备份
- 成功/失败 Telegram 通知
- 自动上传到 GitHub
- 自动清理旧备份
- 详细日志记录

### 日常使用
```bash
# 1. 每周标准备份
./backup.sh weekly-$(date +%Y%m%d)

# 2. 上传到 GitHub（私有仓库）
gh release create v$(date +%Y%m%d) \
  --repo username/openclaw-workspace \
  --title "Weekly Backup" \
  ~/.openclaw/backups/openclaw-weekly-*.tar.gz

# 3. 清理本地旧备份
./cleanup.sh --keep 5
```

### 迁移场景
```bash
# 1. 完整备份（包含敏感数据）
./backup.sh --config config-full.json migration

# 2. 传输到新机器（使用安全方式）
scp ~/.openclaw/backups/openclaw-migration.tar.gz new-machine:~/

# 3. 在新机器上恢复
cd ~/.openclaw/openclaw-backup
./restore.sh ~/openclaw-migration.tar.gz
openclaw gateway restart

# 4. 删除备份文件
rm ~/openclaw-migration.tar.gz
```

## 配置说明

编辑 `config.json` 自定义备份行为：

```json
{
  "openclaw_dir": "~/.openclaw",
  "backup": {
    "auto_discover_workspaces": true,
    "include": {
      "shared": true,
      "agents": false,
      "credentials": false,
      "memory": true
    }
  }
}
```

详细配置选项请查看 `config.json` 和 `config-full.json` 中的注释。

## 版本

v1.1.0 - 2026-03-05

---

**记住：安全第一，便利第二。日常使用标准模式，仅在迁移时使用完整备份。**
