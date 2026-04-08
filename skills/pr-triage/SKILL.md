---
name: pr-triage
description: Triage, audit, and clean up GitHub PRs. Use when reviewing open PRs, checking for stale/conflicting branches, identifying redundant changes, splitting oversized PRs, or deciding merge order. Prevents merging stale code that overwrites stable work. Use before batch-merging or when PR count grows. Triggers on "review PRs", "merge order", "stale PRs", "clean up PRs", "PR audit", "what should we merge".
---

# PR Triage

Systematic process for auditing open PRs and deciding what to merge, rebase, split, or close.

## Configuration

Set these when installing the skill. Update as needed.

```yaml
# Port for the dev server when spinning up live previews
DEV_PORT: 3000
```

## Step 1: Inventory

List all open PRs with status:
```bash
gh pr list --state open --json number,title,headRefName,mergeable,createdAt,files --jq '.[] | "\(.number) | \(.title) | \(.mergeable) | \(.createdAt[:10]) | \(.files | length) files"'
```

## Step 2: Classify Each PR

For every open PR, determine:

### Mergeable?
```bash
gh pr view <N> --json mergeable --jq '.mergeable'
```
- `MERGEABLE` → candidate for merge
- `CONFLICTING` → needs rebase or close
- `UNKNOWN` → GitHub still computing, retry

### Stale Check
A PR is **stale** if its branch diverges significantly from main due to subsequent merges. Detect by comparing unique commits vs total file diff:

```bash
# Unique commits (actual work)
git log origin/main..origin/<branch> --oneline | wc -l

# Total files diffed against main (includes inherited drift)
git diff origin/main..origin/<branch> --name-only | wc -l
```

**Red flag:** If unique commits touch 5 files but the diff shows 80+ files, the branch is stale — it's carrying old versions of files that main has since updated. These extra files would **silently overwrite stable code** without showing as git conflicts.

### Redundancy Check
Compare new files (unique to branch) vs modified files (exist on both):
```bash
# Files only on the branch (genuinely new)
git diff origin/main..origin/<branch> --diff-filter=A --name-only

# Files modified on both (potential overwrites)
git diff origin/main..origin/<branch> --diff-filter=M --name-only
```

If modified files were already updated by recent PRs on main, this PR's versions are likely stale. Verify by checking if another merged PR already addressed the same changes:
```bash
git log origin/main --oneline -- <file> | head -5
```

### Overlap Detection
Check if two PRs touch the same files:
```bash
comm -12 <(git diff origin/main..origin/<branch1> --name-only | sort) \
         <(git diff origin/main..origin/<branch2> --name-only | sort)
```

## Step 3: Categorize

Assign each PR one action:

| Category | Criteria | Action |
|---|---|---|
| **Ready** | Mergeable, builds, no stale files | Merge in dependency order |
| **Rebase** | Good changes but conflicts or stale files | Create clean branch, port unique changes |
| **Split** | Mixes features (e.g., fleet UI + booking flow + documents) | Separate into focused PRs |
| **Redundant** | Changes already landed via another PR | Close with comment |
| **Stale** | Old milestone PR, completely diverged | Close or flag for full rewrite |

## Step 4: Rebase Strategy

When rebasing a stale PR onto main:

### Identify what's actually unique
```bash
git log origin/main..origin/<branch> --oneline  # Unique commits
git diff origin/main..origin/<branch> --diff-filter=A --name-only  # New files only
```

### Safe rebase method
```bash
git checkout -b <clean-branch> main

# Copy ONLY new files from the old branch
git show origin/<old-branch>:<path> > <path>

# For modified files: compare and merge manually
# ALWAYS prefer main for files touched by recent stable PRs
```

### Never do
- `git merge origin/<stale-branch>` — pulls in all the old file versions
- `git checkout origin/<stale-branch> -- <file>` on files that main has updated — overwrites stable code
- `git push origin <new>:<old> --force-with-lease` to update an existing PR — this **destroys the original commit history**. Always push to a new branch and create a new PR. Reference the old PR in the description. The old branch stays intact for reference.
- **`--force-with-lease` or `--force` push** — only two valid cases: (1) fixing commit author attribution (e.g., commits pushed as `stack-dev` instead of `alphak3y`), and (2) scrubbing accidentally committed secrets from history. For everything else — adding changes, fixing bugs, addressing review feedback — make a new commit and push normally. Force-pushing destroys review context and hides history.
- **Rebasing a stale PR** — do NOT force-push the rebased result to the original branch. Instead: create a NEW branch (e.g., `feat/feature-name-v2`), push there, and open a NEW PR referencing the old one. Close the old PR with a comment pointing to the new one. This preserves the original PR's review history and avoids overwriting someone else's branch.

### Conflict-free doesn't mean safe
**Critical lesson:** A stale branch can be `MERGEABLE` (no git conflicts) but still destructive. If main updated a file from v1→v2, and the branch has v1.1, git may auto-merge to v1.1 — losing v2 entirely. Always check what the diff actually contains, not just whether GitHub says it's mergeable.

### Conflicting files may not belong in the repo
Before resolving any conflict, ask: **should this file even be tracked?** Common offenders:
- `tsconfig.tsbuildinfo` — build cache, should be in `.gitignore`
- `package-lock.json` changes from unrelated installs
- `.env` files accidentally committed
- `.next/`, `node_modules/`, `dist/` build artifacts

Check if the file is in `.gitignore` but was committed before the rule existed:
```bash
git check-ignore <file>  # Returns the file if .gitignore would exclude it
```
If it's ignored but still tracked, remove it:
```bash
git rm --cached <file>
```
**Always report these findings to the user** — a one-time cleanup PR prevents the same phantom conflict on every future PR.

## Step 5: Split Strategy

When a PR mixes concerns:

1. Identify distinct feature areas by file path:
   - `src/app/(admin)/` → admin changes
   - `src/app/(storefront)/` → customer-facing
   - `src/domains/<new>/` → new feature domain
   - `supabase/migrations/` → schema changes
   - `src/middleware.ts` → routing (high risk)

2. Create separate branches per concern
3. New/additive files are safe to cherry-pick
4. Modified shared files (middleware, types, booking-state) → prefer main, port only new additions

## Step 6: Merge Order

Sort ready PRs by:
1. **No dependencies** first (additive features, bug fixes)
2. **Schema changes** before code that uses them
3. **Test-only PRs before the features they cover** — merge test suites first so the safety net is in place before big changes land
4. **Smaller PRs** before larger (less conflict surface)
5. **Shared file touches** last (types.ts, middleware.ts, booking-state.ts)

### Zero-Overlap Fast Path

If no open PRs share any files (check with overlap detection in Step 2), merge order is a **preference not a requirement**. The staleness/overwrite risks don't apply when files are completely disjoint. In this case, just prioritize by risk: smallest/safest first, biggest last.

### Same-Session PR Batches

When a single subagent creates multiple PRs in one session, they're all branched from the same `main` commit. This means:
- **Staleness risk is near-zero** — no time for main to drift between branches
- **Overlap is the only concern** — check file overlap, skip the full staleness analysis
- **Any merge order works** if files don't overlap

This is a concrete time-saver: skip Steps 2-3 staleness checks for same-session batches and go straight to overlap detection. If clean, merge in preference order (small→tests→features).

## PR Workflow Rules

**One PR per branch, one branch per PR. Never reuse.**

### Always start from latest default branch

Every new branch MUST start from the latest commit on the default branch (usually `main`). This is non-negotiable — stale bases cause the majority of conflict and overwrite issues.

```bash
# Before creating any branch:
git fetch origin
git checkout -b feat/my-feature origin/main
```

**Never branch from:**
- A local `main` that hasn't been pulled (could be days behind)
- Another feature branch (unless it's a deliberate stacked PR)
- An old tag or commit

**For subagent/repo-slot workflows:**
```bash
# repo-slot.sh already handles this, but verify:
git fetch origin
git reset --hard origin/main
```

**If your branch is already behind main** (e.g., main moved while you were working), sync before pushing:
```bash
git fetch origin
git merge origin/main  # resolve conflicts if any
# OR for clean history:
git rebase origin/main
```

### Branch lifecycle

- **Before pushing to any branch**, check if its PR has been merged or closed:
  ```bash
  gh pr list --head <branch-name> --state all --json number,state --jq '.[0]'
  ```
  If `state: "MERGED"` or `state: "CLOSED"` → that branch is done. Create a new one.
- For follow-up work, always create a new branch off current `main` and a new PR.
- Even if the follow-up is closely related to the previous PR, start fresh.
- Name new branches descriptively: `feat/dual-role-nav` not `feat/session-aware-header-v2`.
- Reference the previous PR in the new PR description for context.

## Git Identity

**Every commit must be attributed to a real GitHub account.** Vercel and GitHub reject or flag commits from unknown authors (`stack-dev`, `Ubuntu`, etc.).

Before your first commit in any repo:
```bash
git config user.name "alphak3y"
git config user.email "84204260+alphak3y@users.noreply.github.com"
```

**For subagent prompts**, always include in the `[GIT]` or `[CONSTRAINTS]` section:
```
Use the git identity: git config user.name "alphak3y" && git config user.email "84204260+alphak3y@users.noreply.github.com"
```

The `84204260+alphak3y@users.noreply.github.com` noreply address:
- Links commits to the `alphak3y` GitHub account
- Doesn't expose a real email
- Works even with "Block command line pushes that expose my email" enabled

**Why this matters:** Vercel preview deployments and GitHub checks will fail or skip for commits from unrecognized authors. One bad commit = redo the PR.

## Test Requirements

**Every PR that changes source code must include or update tests.**

Before merging, verify:

1. **New feature?** → Must include unit tests covering the happy path + edge cases
2. **Bug fix?** → Must include a regression test that would have caught the bug
3. **Refactor?** → Existing tests must still pass. If behavior changed, update tests.
4. **Schema change?** → Update schema sync test if new tables/columns added
5. **API route change?** → Update API smoke tests (401/403 checks, new endpoints)
6. **Scoring/pipeline change?** → Update scoring tests with new signals

**Run before pushing:**
```bash
npx vitest run
```

**CI enforces this:** Tests run on every PR. If tests fail, PR can't merge.

**For subagent prompts**, always include in `[CONSTRAINTS]`:
```
- Write tests for any new or changed functionality
- Run `npx vitest run` — all tests must pass
- If modifying existing functions, update their tests to cover the change
```

## Database Migration Checklist

**Every PR that touches schema or adds columns must include:**

1. **Migration SQL file** in `supabase/migrations/` with the correct timestamp
2. **Consolidated schema updated** — `supabase/consolidated/schema.sql` must reflect the final state
3. **RLS policies** for any new tables (check existing patterns)
4. **Indexes** for any new foreign keys or frequently queried columns

**Before merging:** Identify the exact SQL that needs to run on the live Supabase DB. Include it in the PR description or review comment as a ready-to-paste block:

```
## Post-Merge SQL (run in Supabase SQL Editor)

<paste the migration SQL here>
```

This prevents the "merged the code but forgot to run the migration" problem. The reviewer (Cortana or Mike) should always surface the specific SQL commands needed pre/post merge.

**Watch for missing columns:** If the consolidated schema was rebuilt from old migrations, some columns may exist in `schema.sql` but not in the live DB. Always verify new columns actually exist before creating indexes that reference them.

## Writing Subagent Prompts

When dispatching work to a subagent (or structuring your own task), a good prompt has six parts:

```
[CONTEXT]
What exists today, what was recently changed, relevant patterns.
Include recent PR numbers or commits that relate to this work.

[FILES TO READ]
Exact file paths the agent should read before starting.
Don't say "look at the auth folder" — say "src/components/auth/AuthProvider.tsx".

[TASK]
Specific deliverable with clear scope. Use sub-tasks (a, b, c) for multi-file changes.
One task per agent — don't overload.

[CONSTRAINTS]
- Don't install new packages
- Don't modify test files
- Don't run the dev server
- TypeScript must compile clean (`npx tsc --noEmit`)
- Commit with descriptive message and push

[GIT]
Branch name, base branch, git identity:
  git config user.name "yourname"
  git config user.email "id+yourname@users.noreply.github.com"

[SUCCESS CRITERIA]
What "done" looks like. Be specific:
- "Login from /dashboard redirects back to /dashboard after auth"
- "Fleet items can go live regardless of waiver readiness"
- "`npx tsc --noEmit` passes"
```

### Tips
- **Be specific about files** — list exact paths, not directories
- **Include context from today's work** — what was just built, what patterns to follow
- **Set constraints early** — saves wasted work (e.g., "don't install packages")
- **One task per agent** — focused prompts get better results
- **Multi-PR runs** — for 2+ independent changes, structure as `[TASK 1 — Branch: fix/x]` and `[TASK 2 — Branch: feat/y]` in one prompt. One context load, multiple atomic PRs.

### Multi-PR prompt pattern

```
[TASK 1 — Branch: fix/thing-a]
Create branch from <base>, implement change, commit, push.

[TASK 2 — Branch: feat/thing-b]
Checkout <base> again, create branch, implement, commit, push.
```

Each task gets its own branch, its own PR, its own review. Cheaper than N separate agent runs.

## Live Preview for PR Testing

After a subagent finishes work on a PR branch, it should spin up a dev server so changes can be tested live before merging.

### When to spin up a live preview

**Frontend apps only.** If the PR changes a web app with a UI (Next.js, React, Vue, etc.), spin up a dev server so reviewers can click through the changes.

Do NOT start a server for:
- Backend-only services (APIs without a UI)
- CLI tools, scripts, or libraries
- Config-only changes
- Documentation

### Add to subagent prompts (frontend PRs)

Replace `{{DEV_PORT}}` with your configured port.

```
[POST-COMPLETION]
After all tasks pass tsc, start the dev server for manual testing:
  # Kill any existing dev server on the configured port first
  lsof -ti:{{DEV_PORT}} | xargs kill -9 2>/dev/null || true
  npx next dev --turbopack -p {{DEV_PORT}}
Report the URL (http://localhost:{{DEV_PORT}}) so changes can be tested live.
Do NOT kill the server — leave it running for the reviewer.
```

### Guidelines
- Use the port from `DEV_PORT` in your configuration (default: 3000)
- Kill any existing process on that port before starting
- Only one dev server at a time
- The server stays up until the orchestrator or user explicitly kills it

### Why this matters
GitHub's `MERGEABLE` status and `tsc` passing don't catch UI regressions, broken auth flows, or misconfigured redirects. A live preview lets the reviewer (human or orchestrator) click through the actual app on the feature branch before approving.

## Anti-Patterns

| ❌ Don't | ✅ Do |
|---|---|
| Merge a 90-file PR without checking for stale files | Count unique commits vs total diff |
| Trust `MERGEABLE` status alone | Verify the diff doesn't overwrite recent work |
| Rebase by merging the old branch | Cherry-pick only unique/new files onto clean branch |
| Leave 20+ open PRs accumulating | Triage weekly — close stale, rebase active |
| Merge PRs that mix features + fixes + refactors | Split into focused PRs first |
