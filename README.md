# OpenClaw 备份工具

OpenClaw 配置的完整备份和恢复解决方案。

## ⚠️ 重要安全提示

**OpenClaw 配置包含敏感信息，备份时需要特别注意安全！**

### 敏感信息清单

**🔴 高度敏感（不应公开）**：
- `.env` - API 密钥（Claude, OpenAI, Tavily, Brave 等）
- `auth-profiles.json` - OAuth tokens 和认证凭证
- `credentials/` - 各种服务的凭证
- `openclaw.json` 中的 Telegram bot tokens

**风险**：泄露后可能导致账户被盗用、产生费用、服务被滥用

**🟡 中度敏感（谨慎分享）**：
- `memory/*.sqlite` - 完整的对话历史
- `workspace/memory/*.md` - 日常工作日志和项目讨论

**风险**：隐私泄露、工作信息泄露

### 两种备份模式

**标准模式（默认）- 安全** ✅
- 排除所有敏感文件（.env, auth-profiles.json, credentials/）
- 可以安全上传到 GitHub（公开或私有仓库）
- 适用于日常备份、分享配置

**完整模式 - 包含敏感信息** ⚠️
- 包含所有文件，包括 API 密钥和凭证
- **不要上传到公开仓库！**
- 仅用于迁移到新机器、灾难恢复
- 使用后应立即删除

## 快速开始

```bash
cd ~/.openclaw/openclaw-backup

# 标准备份（安全，排除敏感信息）
./backup.sh

# 完整备份（包含 API 密钥等敏感信息）
./backup.sh --config config-full.json full-backup

# 恢复
./restore.sh ~/.openclaw/backups/openclaw-backup-xxx.tar.gz
```

## 特性

✅ **自动发现** - 自动查找所有工作空间，无需手动配置
✅ **路径可移植** - 支持 VPS ↔ 本地无缝迁移
✅ **配置驱动** - 通过 config.json 灵活控制备份内容
✅ **安全可靠** - 恢复前自动备份现有配置
✅ **预览模式** - 使用 --dry-run 查看将要恢复的内容
✅ **双模式备份** - 标准模式安全，完整模式用于迁移

## 文件说明

- `backup.sh` - 备份脚本
- `restore.sh` - 恢复脚本
- `cleanup.sh` - 清理旧备份
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

# 完整备份（包含敏感信息）
./backup.sh --config config-full.json migration

# 显示详细信息
./backup.sh --verbose

# 查看帮助
./backup.sh --help
```

### 恢复
```bash
# 基本恢复
./restore.sh ~/.openclaw/backups/openclaw-backup-xxx.tar.gz

# 预览模式（不实际修改）
./restore.sh backup.tar.gz --dry-run

# 显示详细信息
./restore.sh backup.tar.gz --verbose
```

## 备份内容对比

| 项目 | 标准模式 | 完整模式 |
|------|---------|---------|
| openclaw.json | ✅ | ✅ |
| .env（API 密钥） | ❌ | ⚠️ |
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

### 2. 完整备份仅用于迁移
```bash
# 迁移前
./backup.sh --config config-full.json migration

# 迁移后立即删除
rm ~/.openclaw/backups/openclaw-migration.tar.gz
```

### 3. 上传到 GitHub 前检查
```bash
# 检查是否包含敏感文件
tar -tzf ~/.openclaw/backups/openclaw-backup-xxx.tar.gz | grep -E "(\.env|auth-profiles|credentials)"

# 如果有输出，说明包含敏感文件，不要上传！
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

## 泄露后的应对措施

如果不小心泄露了包含敏感信息的备份：

1. **立即撤销 API 密钥**
   - Claude API: https://console.anthropic.com/settings/keys
   - OpenAI: https://platform.openai.com/api-keys
   - 其他服务：各自的控制台

2. **删除泄露的文件**
   - 从 GitHub 删除（如果上传了）
   - 清空 Git 历史（如果提交了）

3. **重新生成凭证**
   - 生成新的 API 密钥
   - 更新 `.env` 文件
   - 重新配置 Telegram bots

4. **检查账户活动**
   - 查看 API 使用记录
   - 检查异常调用
   - 监控费用变化

## 推荐工作流

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
# 1. 完整备份（包含敏感信息）
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

## 配置

编辑 `config.json` 来自定义备份行为：

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

详细配置说明请查看 `config.json` 和 `config-full.json` 中的注释。

## 版本

v1.0.0 - 2026-03-05

---

**记住：安全第一，便利第二。日常使用标准模式，完整备份仅用于迁移。**
