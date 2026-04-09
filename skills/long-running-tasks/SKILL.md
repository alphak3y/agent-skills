---
name: long-running-tasks
description: Run long-running batch jobs (enrichment pipelines, bulk scraping, data processing) that survive OpenClaw's exec sandbox timeout. Use when a task takes more than 60 seconds, when exec processes keep getting SIGKILL'd, when running batch operations over large datasets, or when you need a background job that persists across agent turns. Triggers on "OOM", "SIGKILL", "exec killed", "long running", "batch process", "background job", "enrichment pipeline", "bulk scrape".
---

# Long-Running Tasks

Run batch jobs that outlive the exec sandbox by detaching them into tmux sessions.

## The Problem

OpenClaw's exec sandbox kills processes that run too long or consume too much memory within a single tool call. Symptoms:
- `Process exited with signal SIGKILL`
- Jobs die silently after 30-120 seconds
- `nohup` doesn't help (sandbox tracks the process group)

## The Fix: tmux

tmux sessions are **not** children of the exec sandbox. A process inside tmux survives after the exec call returns.

### Start a background job

```bash
tmux new-session -d -s <session-name> "<command> 2>&1 | tee /tmp/<logfile>.log"
```

### Check progress

```bash
tail -20 /tmp/<logfile>.log
```

### Check if still running

```bash
tmux has-session -t <session-name> 2>/dev/null && echo "RUNNING" || echo "STOPPED"
```

### Kill it

```bash
tmux kill-session -t <session-name>
```

## Batch Processing Pattern

For large datasets (thousands of files), **never** pass an entire directory to a script that loads everything into memory. Write a wrapper that processes one file at a time:

```bash
#!/bin/bash
# Process files sequentially to avoid OOM on memory-constrained instances
SCRIPT="path/to/processor.py"
LOGFILE="/tmp/batch-process.log"
TOTAL=$(ls input/*.json | wc -l)
DONE=0

echo "Starting: $TOTAL files" | tee "$LOGFILE"

for f in input/*.json; do
    DONE=$((DONE + 1))
    BASENAME=$(basename "$f")
    echo "[$DONE/$TOTAL] $BASENAME" | tee -a "$LOGFILE"
    python3 "$SCRIPT" --input "$f" >> "$LOGFILE" 2>&1
done

echo "Finished at: $(date -u)" | tee -a "$LOGFILE"
```

Then run it in tmux:

```bash
tmux new-session -d -s batch "bash scripts/batch_wrapper.sh 2>&1 | tee /tmp/batch.log"
```

## Memory Rules (3.7GB EC2)

| Concurrency | Use case | Notes |
|-------------|----------|-------|
| 1 | API calls, heavy processing | Safest |
| 3 | HTTP scraping (lightweight) | Good default |
| 5 | Tiny requests only | Watch memory |
| 10+ | **Don't** | OOM guaranteed |

Before starting a heavy job:
```bash
# Drop filesystem caches (safe, frees 500MB-1.5GB)
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
free -h
```

## Monitoring from Heartbeats

Add a check to `HEARTBEAT.md`:

```markdown
## Background Job: <name>
- Check: `tmux has-session -t <name> 2>/dev/null && echo "RUNNING" || echo "DONE"`
- If DONE, check results: `tail -20 /tmp/<logfile>.log`
- If RUNNING, report progress: `tail -5 /tmp/<logfile>.log`
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| `nohup` still gets killed | Use tmux, not nohup |
| Script loads all files then processes | Wrap in per-file bash loop |
| Concurrency too high → OOM | Max 3 for HTTP, 1 for heavy |
| Forgot to log progress | Always `tee` to a log file |
| Lost track of what's running | Name tmux sessions descriptively |
| Job finished but nobody noticed | Add heartbeat monitor |
