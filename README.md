# OpenClaw Backup Tool

Complete backup and restore solution for OpenClaw configurations.

English | [简体中文](README.zh-CN.md)

## Installation

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/JAMESHPF/openclaw-backup/main/install.sh | bash

# Or manual install
git clone https://github.com/JAMESHPF/openclaw-backup.git ~/.openclaw/openclaw-backup
cd ~/.openclaw/openclaw-backup && chmod +x *.sh
```

**Requirements:** OpenClaw, jq or python3, git

**Platform:** macOS / Linux. Runs anywhere OpenClaw runs — local Mac, VPS (Ubuntu/Debian/CentOS), WSL2.

## Quick Start

```bash
cd ~/.openclaw/openclaw-backup

./backup.sh                    # Standard backup (safe)
./backup.sh my-backup          # Custom backup name
./backup.sh --verbose          # Verbose output

./restore.sh <backup.tar.gz>   # Restore from backup
./restore.sh <file> --dry-run  # Preview only

./cleanup.sh                   # Keep last 10 backups
./cleanup.sh --keep 5          # Keep last 5
```

Backups are saved to `~/.openclaw/backups/`.

## Backup Modes

This tool has two modes to balance security and completeness:

| | ✅ Standard (default) | ⚠️ Full |
|---|---|---|
| **Command** | `./backup.sh` | `./backup.sh --config config-full.json` |
| **Use case** | Daily backup, config sharing | Machine migration, disaster recovery |
| 📋 openclaw.json | ✅ Included | ✅ Included |
| 📁 Workspaces | ✅ Included | ✅ Included |
| 🤝 Shared resources | ✅ Included | ✅ Included |
| 🧠 Memory data | ✅ Included | ✅ Included |
| 🔑 .env (API keys) | ❌ Excluded | ⚠️ Included |
| 🔐 auth-profiles.json | ❌ Excluded | ⚠️ Included |
| 🔐 credentials/ | ❌ Excluded | ⚠️ Included |
| 🤖 agents/ | ❌ Excluded | ⚠️ Included |
| **Safe for GitHub?** | ✅ Yes | ❌ No - contains secrets |

> **Rule of thumb:** Use standard mode for everything except machine migration. Delete full backups immediately after use.

> [!WARNING]
> Even in standard mode, `openclaw.json` is included. Make sure your `openclaw.json` does not contain plaintext API keys or bot tokens — store them in `.env` and reference via environment variables instead.

## Configuration

Edit `config.json` to customize what gets backed up:

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

`config-full.json` is the same but with all includes set to `true` and `.env` / `auth-profiles.json` added to `core_config`.

## Path Portability

Backups automatically replace absolute paths with placeholders (`{{HOME}}`, `{{OPENCLAW_DIR}}`), so you can restore on a different machine or user account without manual path editing. Restore reverses this automatically.

## GitHub Integration

Upload standard backups to GitHub Releases for off-site storage:

```bash
# Upload
gh release create v$(date +%Y%m%d) \
  --repo username/openclaw-workspace \
  --title "Backup $(date +%Y-%m-%d)" \
  ~/.openclaw/backups/openclaw-backup-*.tar.gz

# Download and restore
gh release download v20260305 --repo username/openclaw-workspace
./restore.sh openclaw-backup-20260305.tar.gz
openclaw gateway restart
```

## Migration Workflow

```bash
# 1. Full backup on old machine
./backup.sh --config config-full.json migration

# 2. Transfer securely
scp ~/.openclaw/backups/openclaw-migration.tar.gz new-machine:~/

# 3. Restore on new machine
cd ~/.openclaw/openclaw-backup
./restore.sh ~/openclaw-migration.tar.gz
openclaw gateway restart

# 4. Clean up
rm ~/openclaw-migration.tar.gz
```

## Security

### Before uploading any backup

```bash
# Verify no sensitive files are included
tar -tzf <backup.tar.gz> | grep -E "(\.env|auth-profiles|credentials)"
# If output is empty, safe to upload
```

### Encrypt full backups (optional)

```bash
gpg --encrypt --recipient your@email.com backup.tar.gz
rm backup.tar.gz  # Delete unencrypted original
```

### If credentials are exposed

1. **Revoke API keys immediately** - [Claude](https://console.anthropic.com/settings/keys), [OpenAI](https://platform.openai.com/api-keys), and any other services
2. **Remove exposed files** from GitHub and clear git history
3. **Regenerate all credentials** and update `.env`
4. **Monitor account activity** for unauthorized usage

## Files

| File | Description |
|------|-------------|
| `backup.sh` | Create backups with auto-discovery and checksum generation |
| `restore.sh` | Restore with integrity verification, path auto-fix, and pre-restore safety backup |
| `cleanup.sh` | Remove old backups, keeping the most recent N |
| `config.json` | Standard mode config - excludes sensitive files |
| `config-full.json` | Full mode config - includes everything |
| `install.sh` | One-line installer with dependency checks |

## Version

v1.1.0 - 2026-03-05

## License

MIT
