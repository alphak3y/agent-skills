---
name: taskbot
description: Persistent task tracker with date-based reminders. Use when the user wants to add, list, complete, or be reminded of tasks. Triggers on words like "task", "todo", "remind me", "remember to", "taskbot", or any request to track/schedule work. Also used during heartbeats to check for due reminders.
---

# Taskbot

Persistent task management with reminders. Tasks live in a JSON file and get surfaced during heartbeats when due.

## Task Store

Tasks are stored in `~/.openclaw/workspace/tasks.json`. Use the management script for all operations:

```bash
python3 ~/.openclaw/workspace/skills/taskbot/scripts/tasks.py <command> [args]
```

## Commands

### Add a task
```bash
python3 scripts/tasks.py add "Task description" [--due "YYYY-MM-DD HH:MM"] [--priority high|medium|low] [--tags tag1,tag2]
```
- `--due` accepts ISO datetime or date-only (assumes 09:00 user timezone)
- Default priority: medium
- Tags are optional, comma-separated

### List tasks
```bash
python3 scripts/tasks.py list [--status open|done|all] [--tag tagname] [--priority high]
```
- Default: shows open tasks only
- Supports filtering by tag and priority

### Complete a task
```bash
python3 scripts/tasks.py done <task_id>
```

### Delete a task
```bash
python3 scripts/tasks.py delete <task_id>
```

### Check due reminders
```bash
python3 scripts/tasks.py due [--window 60]
```
- Returns tasks due within the next N minutes (default: 60)
- Use during heartbeats to surface reminders

### Snooze a task
```bash
python3 scripts/tasks.py snooze <task_id> <minutes>
```

## Heartbeat Integration

During heartbeats, run `tasks.py due` to check for upcoming tasks. If any are due:
1. Surface them to the user with context
2. Don't repeat reminders already delivered in the same heartbeat window

## Conventions

- Store dates in UTC internally, convert to user timezone (MDT/MST) for display
- **Default due date: tomorrow at 9:00 AM MDT** — always set this unless the user specifies a different date
- Task IDs are short random strings (6 chars)
- Completed tasks stay in the file (marked done) for history
- When the user says "remind me" or "remember to", create a task with a due date
