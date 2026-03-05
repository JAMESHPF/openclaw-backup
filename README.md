# OpenClaw Backup Tool

Complete backup and restore solution for OpenClaw configurations.

## 📦 Installation

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/JAMESHPF/openclaw-backup/main/install.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/JAMESHPF/openclaw-backup.git ~/.openclaw/openclaw-backup
cd ~/.openclaw/openclaw-backup
chmod +x *.sh
```

### Requirements

- OpenClaw (required)
- jq or python3 (required for config parsing)
- git (required for installation)

## ⚠️ Important Security Notice

**OpenClaw configurations contain sensitive information. Handle backups with care!**

### Sensitive Information Checklist

**🔴 Highly Sensitive (Never Share Publicly)**:
- `.env` - API keys (Claude, OpenAI, Tavily, Brave, etc.)
- `auth-profiles.json` - OAuth tokens and authentication credentials
- `credentials/` - Service credentials
- Telegram bot tokens in `openclaw.json`

**Risk**: Exposure may lead to account compromise, unauthorized charges, service abuse

**🟡 Moderately Sensitive (Share Cautiously)**:
- `memory/*.sqlite` - Complete conversation history
- `workspace/memory/*.md` - Daily work logs and project discussions

**Risk**: Privacy breach, work information exposure

### Two Backup Modes

**Standard Mode (Default) - Safe** ✅
- Excludes all sensitive files (.env, auth-profiles.json, credentials/)
- Safe to upload to GitHub (public or private repos)
- Suitable for daily backups and config sharing

**Full Mode - Contains Sensitive Data** ⚠️
- Includes all files including API keys and credentials
- **DO NOT upload to public repositories!**
- Only for machine migration and disaster recovery
- Delete immediately after use

## Quick Start

```bash
cd ~/.openclaw/openclaw-backup

# Standard backup (safe, excludes sensitive info)
./backup.sh

# Full backup (includes API keys and sensitive data)
./backup.sh --config config-full.json full-backup

# Restore
./restore.sh ~/.openclaw/backups/openclaw-backup-xxx.tar.gz
```

## Features

✅ **Auto-Discovery** - Automatically finds all workspaces without manual configuration
✅ **Path Portability** - Supports VPS ↔ Local seamless migration
✅ **Config-Driven** - Flexible backup control via config.json
✅ **Safe & Reliable** - Auto-backup existing config before restore
✅ **Preview Mode** - Use --dry-run to preview restore contents
✅ **Dual Backup Modes** - Standard mode for safety, full mode for migration

## Files

- `backup.sh` - Backup script
- `restore.sh` - Restore script
- `cleanup.sh` - Cleanup old backups
- `config.json` - Standard config (excludes sensitive files) ⭐
- `config-full.json` - Full config (includes sensitive files) ⚠️
- `QUICKSTART.md` - Quick reference card

## Backup Storage

Backups are automatically saved to:
```
~/.openclaw/backups/
├── openclaw-backup-20260305-212504.tar.gz
├── openclaw-backup-20260304-183022.tar.gz
└── ...
```

### Cleanup Old Backups
```bash
# Keep last 10 backups (default)
./cleanup.sh

# Keep last 5 backups
./cleanup.sh --keep 5
```

## Common Commands

### Backup
```bash
# Standard backup (default)
./backup.sh

# Specify name
./backup.sh my-backup

# Full backup (includes sensitive data)
./backup.sh --config config-full.json migration

# Verbose output
./backup.sh --verbose

# Show help
./backup.sh --help
```

### Restore
```bash
# Basic restore
./restore.sh ~/.openclaw/backups/openclaw-backup-xxx.tar.gz

# Preview mode (no actual changes)
./restore.sh backup.tar.gz --dry-run

# Verbose output
./restore.sh backup.tar.gz --verbose
```

## Backup Content Comparison

| Item | Standard Mode | Full Mode |
|------|--------------|-----------|
| openclaw.json | ✅ | ✅ |
| .env (API keys) | ❌ | ⚠️ |
| auth-profiles.json | ❌ | ⚠️ |
| credentials/ | ❌ | ⚠️ |
| Workspaces | ✅ | ✅ |
| Shared resources | ✅ | ✅ |
| Memory data | ✅ | ✅ |
| agents/ | ❌ | ⚠️ |
| **GitHub Public** | ✅ Safe | ❌ Dangerous |
| **GitHub Private** | ✅ Safe | ⚠️ Cautious |

## Security Best Practices

### 1. Use Standard Mode for Daily Backups
```bash
./backup.sh daily-$(date +%Y%m%d)
```

### 2. Full Backup Only for Migration
```bash
# Before migration
./backup.sh --config config-full.json migration

# Delete immediately after migration
rm ~/.openclaw/backups/openclaw-migration.tar.gz
```

### 3. Check Before Uploading to GitHub
```bash
# Check if backup contains sensitive files
tar -tzf ~/.openclaw/backups/openclaw-backup-xxx.tar.gz | grep -E "(\.env|auth-profiles|credentials)"

# If output exists, DO NOT upload!
```

### 4. Encrypt Full Backups (Optional)
```bash
# Encrypt
gpg --encrypt --recipient your@email.com \
  ~/.openclaw/backups/openclaw-full-backup.tar.gz

# Delete unencrypted original
rm ~/.openclaw/backups/openclaw-full-backup.tar.gz
```

## GitHub Integration

### Upload Standard Backup (Safe)
```bash
gh release create v20260305 \
  --repo username/openclaw-workspace \
  --title "Backup 2026-03-05" \
  ~/.openclaw/backups/openclaw-backup-20260305.tar.gz
```

### Download and Restore
```bash
gh release download v20260305 --repo username/openclaw-workspace
./restore.sh openclaw-backup-20260305.tar.gz
openclaw gateway restart
```

## Response to Data Breach

If you accidentally exposed a backup with sensitive information:

1. **Immediately Revoke API Keys**
   - Claude API: https://console.anthropic.com/settings/keys
   - OpenAI: https://platform.openai.com/api-keys
   - Other services: respective control panels

2. **Delete Exposed Files**
   - Remove from GitHub (if uploaded)
   - Clear Git history (if committed)

3. **Regenerate Credentials**
   - Generate new API keys
   - Update `.env` file
   - Reconfigure Telegram bots

4. **Check Account Activity**
   - Review API usage logs
   - Check for anomalous calls
   - Monitor billing changes

## Recommended Workflows

### Daily Use
```bash
# 1. Weekly standard backup
./backup.sh weekly-$(date +%Y%m%d)

# 2. Upload to GitHub (private repo)
gh release create v$(date +%Y%m%d) \
  --repo username/openclaw-workspace \
  --title "Weekly Backup" \
  ~/.openclaw/backups/openclaw-weekly-*.tar.gz

# 3. Cleanup local old backups
./cleanup.sh --keep 5
```

### Migration Scenario
```bash
# 1. Full backup (includes sensitive data)
./backup.sh --config config-full.json migration

# 2. Transfer to new machine (use secure method)
scp ~/.openclaw/backups/openclaw-migration.tar.gz new-machine:~/

# 3. Restore on new machine
cd ~/.openclaw/openclaw-backup
./restore.sh ~/openclaw-migration.tar.gz
openclaw gateway restart

# 4. Delete backup files
rm ~/openclaw-migration.tar.gz
```

## Configuration

Edit `config.json` to customize backup behavior:

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

See comments in `config.json` and `config-full.json` for detailed configuration options.

## Version

v1.1.0 - 2026-03-05

---

**Remember: Security first, convenience second. Use standard mode daily, full backup only for migration.**
