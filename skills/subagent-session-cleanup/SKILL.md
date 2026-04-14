---
name: subagent-session-cleanup
description: "Cleanup stale subagent sessions from OpenClaw session stores. Use when the Control UI sidebar is cluttered with old completed subagent runs, or periodically during heartbeats. Removes session entries and orphaned transcript files. Preserves main, cron, and channel sessions."
---

# Session Cleanup

Remove completed subagent sessions and unauthorized channel sessions. Keeps main sessions, cron sessions, and authorized channel sessions.

## Unauthorized Telegram Session Cleanup

Random users who message the Telegram bot create session entries even when blocked by `allowFrom`. Clean these periodically:

```python
import json
with open('~/.openclaw/agents/main/sessions/sessions.json') as f:
    data = json.load(f)

# Find telegram sessions not from the allowed user
ALLOWED_IDS = ['1603151256']  # Update with your Telegram user ID(s)
unauthorized = [k for k in data.keys() 
                if 'telegram:direct:' in k 
                and not any(uid in k for uid in ALLOWED_IDS)]

for k in unauthorized:
    del data[k]

with open('~/.openclaw/agents/main/sessions/sessions.json', 'w') as f:
    json.dump(data, f, indent=2)
```

Run this in heartbeats (every ~2 hours) or when the Control UI sidebar shows unknown Telegram users.

## When to Use

- Control UI sidebar is cluttered with old subagent runs
- After a batch of subagent work (PR triage, multi-task dispatch)
- During periodic maintenance (heartbeat checks)
- Before sharing screen / demoing the Control UI

## Quick Usage

```bash
# Preview what would be cleaned (dry run)
python3 ~/.openclaw/workspace/skills/subagent-session-cleanup/scripts/cleanup.py

# Actually clean — keep last 1 hour of subagent sessions
python3 ~/.openclaw/workspace/skills/subagent-session-cleanup/scripts/cleanup.py --execute

# Keep last 24 hours instead
python3 ~/.openclaw/workspace/skills/subagent-session-cleanup/scripts/cleanup.py --execute --hours 24

# Remove ALL completed subagent sessions
python3 ~/.openclaw/workspace/skills/subagent-session-cleanup/scripts/cleanup.py --execute --hours 0

# Clean only one agent
python3 ~/.openclaw/workspace/skills/subagent-session-cleanup/scripts/cleanup.py --execute --agent developer
```

## What Gets Cleaned

| Type | Cleaned? | Notes |
|------|----------|-------|
| Subagent sessions older than `--hours` | ✅ Yes | The main target |
| Orphaned transcript files | ✅ Yes | `.jsonl` files with no matching session |
| Main sessions | ❌ Never | Always preserved |
| Cron sessions | ❌ Never | Always preserved |
| Channel sessions (Telegram, etc.) | ❌ Never | Always preserved |

## Also Clean: Repo Slots

Stale repo slots from subagent runs also accumulate in `/home/ubuntu/gitalt/`. These are full git clones and eat disk space.

```bash
# List repo slots
ls -d ~/gitalt/*--stack-* 2>/dev/null

# Remove stale ones (keep any actively in use)
rm -rf ~/gitalt/renta-backend--stack-old-task
```

## Integration with Heartbeats

Add to `HEARTBEAT.md` for periodic cleanup:

```markdown
- Run `python3 ~/.openclaw/workspace/skills/subagent-session-cleanup/scripts/cleanup.py --execute --hours 24` weekly to prune old subagent sessions
```

## Safety

- Always does a dry run by default — must pass `--execute` to delete
- Never touches non-subagent sessions
- Idempotent — safe to run multiple times
