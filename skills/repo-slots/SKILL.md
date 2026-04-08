---
name: repo-slots
description: Manage isolated git repo clones for parallel subagent work. Prevents branch conflicts when multiple agents (e.g., two Stack runs) need to work on the same repo simultaneously. Use when spawning parallel subagents that write to the same codebase, or when dispatching multiple developers to the same repo. Triggers on "repo slot", "parallel agents same repo", "agent clone", or when writing prompts for concurrent dev tasks.
---

# Repo Slots

Isolated git clones named after the subagent task, so parallel agents never collide.

## Problem

Two subagents on the same repo share the working directory → branch conflicts, corrupted uncommitted changes.

## Solution

Each subagent gets its own named clone. The name matches the task label for instant readability:

```
~/gitalt/renta-backend/              ← primary (Cortana only)
~/gitalt/renta-backend--stack-docs/  ← Stack building docs
~/gitalt/renta-backend--stack-legal/ ← Stack building legal pages
```

## Commands

```bash
# Acquire a named slot (clones on first use, reuses after)
scripts/repo-slot.sh acquire <repo-name> <branch> <label>
# Example:
scripts/repo-slot.sh acquire renta-backend feat/docs-site stack-docs
# Output: SLOT:/home/ubuntu/gitalt/renta-backend--stack-docs

# Done — release lock + delete clone (use after subagent pushes)
scripts/repo-slot.sh done ~/gitalt/renta-backend--stack-docs

# Release only (keep clone for reuse)
scripts/repo-slot.sh release ~/gitalt/renta-backend--stack-docs

# Show all slots
scripts/repo-slot.sh list renta-backend

# Remove all unlocked slots (bulk disk cleanup)
scripts/repo-slot.sh cleanup renta-backend
```

## Dispatch Workflow

### 1. Acquire before spawning

```bash
scripts/repo-slot.sh acquire renta-backend feat/docs-site stack-docs
# → SLOT:/home/ubuntu/gitalt/renta-backend--stack-docs
```

### 2. Include slot path in the subagent prompt

```
[REPO]
Work in: ~/gitalt/renta-backend--stack-docs/
Branch: feat/docs-site
Do NOT use ~/gitalt/renta-backend/ — that's the primary copy.
Commit and push when done.
```

### 3. Clean up after completion

Once the subagent pushes and you've verified, delete the clone (branch is on remote — local copy is just disk waste):

```bash
scripts/repo-slot.sh done ~/gitalt/renta-backend--stack-docs
```

Use `release` instead of `done` only if you plan to reuse the same slot for a follow-up run on the same branch.

## Naming Convention

Label = `<agent>-<task>` (e.g., `stack-docs`, `stack-legal`, `stack-encryption`). This makes `list` output immediately readable:

```
🔒 renta-backend--stack-docs  — branch: feat/docs-site, since: 2026-03-31T12:10Z
🔒 renta-backend--stack-legal — branch: feat/legal-pages, since: 2026-03-31T12:10Z
🟢 renta-backend--stack-perf  — free (on: main)
```

## Rules

- **Primary repo** (`~/gitalt/<repo>/`) — Cortana only. Reviews, quick fixes, one-at-a-time.
- **Named slots** — One per concurrent subagent task. Always specify in the prompt.
- **Release promptly** — After agent completes, release to reset the clone.
- **Clones persist** — `acquire` reuses existing clones (fast). Use `cleanup` to free disk.
