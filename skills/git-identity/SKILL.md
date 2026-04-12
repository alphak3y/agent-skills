---
name: git-identity
description: Ensure git commits are attributed to the correct GitHub account. Use in every subagent prompt that involves git commits to prevent "No GitHub account was found matching the commit" errors on GitHub.
---

# Git Identity

GitHub rejects commits (or shows them as unlinked) when the commit author email doesn't match any GitHub account. This happens when agents commit from cloned repos without proper git config.

## The Problem

Repo slot clones and fresh clones default to the system user (`Ubuntu <ubuntu@hostname>`). GitHub can't link those commits to any account → "No GitHub account was found matching the commit" warning on PRs.

## The Fix

**Before your first commit** in any repo, verify git identity is set:

```bash
# Check current identity
git config user.name && git config user.email

# If empty or wrong, set it:
git config user.name "alphak3y"
git config user.email "84204260+alphak3y@users.noreply.github.com"
```

## For Subagent Prompts

Add these lines to the `[CONSTRAINTS]` section of every Stack/developer prompt:

```
- Git identity: `git config user.name "alphak3y" && git config user.email "alphak3y@users.noreply.github.com"`
- Do NOT force push. Do NOT use --amend. Make fixup commits instead — we squash on merge.
- Force push is ONLY allowed for rebases (when explicitly instructed to rebase).
```

## Git Push Rules

**Never force push, never amend.** We squash and merge, so extra commits are fine — they disappear on merge.

```bash
# ❌ WRONG — destroys review context, hides history
git commit --amend --no-edit && git push --force-with-lease

# ✅ CORRECT — just add another commit
git commit -m "fix: address review feedback" && git push
```

**Only two valid force-push scenarios:**
1. Rebasing onto latest main (when explicitly told to rebase)
2. Scrubbing accidentally committed secrets from history

Everything else — adding changes, fixing bugs, addressing review feedback — gets a new commit.

## Automated (Repo Slots)

If using `repo-slot.sh acquire`, git identity is set automatically during acquisition — it copies from global config or the primary repo. No manual step needed.

## Why the noreply Email?

`84204260+alphak3y@users.noreply.github.com` is the GitHub-provided noreply address. It:
- Links commits to the `alphak3y` GitHub account
- Doesn't expose a real email in public repos
- Works even if "Block command line pushes that expose my email" is enabled in GitHub settings
