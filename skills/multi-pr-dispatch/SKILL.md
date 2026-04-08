---
name: multi-pr-dispatch
description: Dispatch a single subagent run that produces multiple independent PRs (one branch per task). Use when a feature has 2+ logically independent changes that should be reviewed/tested/merged separately. Saves tokens vs multiple runs while keeping PRs atomic.
---

# Multi-PR Dispatch — One Agent Run, Multiple Branches

## When to Use

- A feature request has 2+ logically independent changes
- You want small, reviewable PRs but don't want to pay for N separate subagent runs
- Changes touch different files/components with no interdependencies

## When NOT to Use

- Truly atomic single-file fix — just one branch
- Tasks that depend on each other's output (task 2 needs task 1's code)
- Different agents needed (e.g., Pixel for design + Stack for code)

## Prompt Structure

Use repo-slots skill to acquire ONE slot, then structure the prompt with multiple tasks:

```
You are Stack 💻. Multiple independent fixes, each on its own branch.

[REPO]
Work in: ~/gitalt/renta-backend--stack-fixes/
Start from main for each task.

[TASK 1 — Branch: fix/waiver-scroll-hint]
<scoped description>
When done: commit, push, then `git checkout main` before starting next task.

[TASK 2 — Branch: feat/sticky-continue-bar]
<scoped description>
When done: commit, push, then `git checkout main` before starting next task.

[TASK 3 — Branch: fix/addons-loading]
<scoped description>
When done: commit, push.

[CONSTRAINTS]
- git checkout main between each task
- Each branch starts fresh from main
- Each task gets its own descriptive commit message
- Push each branch when done
```

## Key Details

### Branch Isolation
Each task MUST start from `main`. The prompt must include:
```
When done: commit, push, then `git checkout main` before starting next task.
```
Without this, Task 2 will include Task 1's changes.

### Repo Slot
Use one repo slot for all tasks — the agent switches branches within it:
```bash
repo-slot.sh acquire renta-backend main stack-batch-fixes
```

### Git Identity
Include once at the top of constraints, not per-task:
```
- Before first commit: git config user.name "alphak3y" && git config user.email "..."
```

### Task Scoping
Each task should be independently testable. If Task 2 depends on Task 1 being merged first, they should NOT be in the same multi-PR dispatch — use sequential single runs instead.

### PR Creation
If gh CLI can't create PRs (PAT scope), list the PR creation URLs in the completion summary:
```
PRs to create:
- https://github.com/org/repo/pull/new/fix/waiver-scroll-hint
- https://github.com/org/repo/pull/new/feat/sticky-continue-bar
- https://github.com/org/repo/pull/new/fix/addons-loading
```

## Benefits

| Approach | Token cost | PRs | Context loads |
|----------|-----------|-----|---------------|
| 3 separate Stack runs | 3× | 3 | 3 |
| 1 multi-PR dispatch | 1× | 3 | 1 |

Same number of reviewable PRs, ~1/3 the cost.

## Review After Completion

Always review the output — verify:
- Each branch only contains its own changes (no bleed between tasks)
- Commits are clean and descriptive
- Build passes on each branch independently
