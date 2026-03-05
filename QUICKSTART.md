# OpenClaw Backup Tool - Quick Start

## One-Minute Setup

### Install
```bash
curl -fsSL https://raw.githubusercontent.com/JAMESHPF/openclaw-backup/main/install.sh | bash
```

### Use
```bash
cd ~/.openclaw/openclaw-backup

# Backup
./backup.sh

# Restore
./restore.sh ~/.openclaw/backups/openclaw-backup-xxx.tar.gz
```

## Common Commands

### Specify Backup Name
```bash
./backup.sh my-backup-name
```

### Show Help
```bash
./backup.sh --help
./restore.sh --help
```

### Preview Restore (No Actual Changes)
```bash
./restore.sh backup.tar.gz --dry-run
```

### Verbose Output
```bash
./backup.sh --verbose
./restore.sh backup.tar.gz --verbose
```

## Configuration

Edit `config.json`:

```json
{
  "openclaw_dir": "~/.openclaw",
  "backup": {
    "include": {
      "shared": true,      // Shared resources
      "agents": false,     // Agents config
      "credentials": false, // Credentials (sensitive)
      "memory": true       // Memory data
    }
  }
}
```

## GitHub Integration

### Upload
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

## Need Help?

See `README.md` for full documentation.
