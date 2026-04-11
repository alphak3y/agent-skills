---
name: subagent-development
description: "Use when executing implementation plans with independent tasks. Dispatches a fresh subagent per task via sessions_spawn, with two-stage review (spec compliance → code quality) after each."
---

# Subagent-Driven Development

Execute plans by dispatching a fresh subagent per task. Fresh context prevents confusion accumulation.

## When to Use

- Have an implementation plan with independent tasks
- Tasks are mostly independent (not tightly coupled)
- Want fast iteration without human-in-loop between tasks

## Execution Loop

Per task:

1. **Dispatch implementer** — spawn subagent with task context (see `references/implementer-prompt.md`)
2. **Handle status:**
   - **DONE** → proceed to spec review
   - **DONE_WITH_CONCERNS** → read concerns, address if substantive, then review
   - **NEEDS_CONTEXT** → provide missing info, re-dispatch
   - **BLOCKED** → more context, more capable model, smaller task, or escalate to human
3. **Spec review** — spawn reviewer (see `references/spec-reviewer-prompt.md`)
4. **Quality review** — only after spec review passes (see `references/quality-reviewer-prompt.md`)
5. **If review fails** → fix and re-review (max 3 iterations, then escalate)
6. **Mark task complete** → next task

After all tasks: spawn a final quality reviewer for the entire implementation.

## Timeout Strategy

Default timeout: **20 minutes** (not 10). Most real dev work needs more than 10 minutes, and there's zero cost if it finishes early.

### Tiered by complexity

| Task Type | Timeout | Examples |
|-----------|---------|----------|
| Quick fix (< 5 files, < 100 lines) | 10 min | One-liner patch, config change, delete dead code |
| Medium (feature work, refactors) | 20 min | Auth guards, API endpoints, component rewrites |
| Heavy (large content generation, multi-file rewrites) | 45 min | 10 full legal templates, DB consolidation, major migrations |

### "Write first" rule for heavy tasks

When a task involves reading large reference files (1000+ lines) AND producing large output, add this to the prompt:

> **Skim files for structure and key patterns, then start writing immediately. Do not read every line of every file before beginning output.**

This prevents the failure mode where the agent spends the entire timeout reading and never produces output.

### When to split instead

If a task has N independent units (e.g., 10 templates, 5 API routes), consider splitting into 2 runs of N/2 each:
- Each finishes faster
- Partial progress survives if one fails
- Only worth it if units are truly independent (no shared state between them)

Reserve splitting for tasks estimated at 30+ minutes. For anything under that, a single run with adequate timeout is simpler.

## Refactor & Rename Safety

When a task involves renaming exports, moving files, or refactoring imports across many files, **always include "run the test suite" as a constraint in the prompt.** Mechanical renames routinely miss test mocks, fixture imports, and type references that don't show up until tests run.

Standard constraint to add:

> After all changes, run the project's test suite (e.g. `npx vitest run`, `npm test`) and fix any failures before committing.

This applies to any rename/refactor touching 5+ files. For smaller changes, use judgment.

## Model Selection

Use the least powerful model that can handle each role:

| Task Type | Model Tier | Signals |
|-----------|-----------|---------|
| Mechanical (1-2 files, clear spec) | Fast/cheap | Isolated function, boilerplate |
| Integration (multi-file coordination) | Standard | Pattern matching, debugging |
| Architecture/review | Most capable | Design judgment, broad codebase |

## OpenClaw Integration

Dispatch subagents via `sessions_spawn`:

```
sessions_spawn(
  task: "[constructed from implementer-prompt.md template]",
  runtime: "subagent",
  mode: "run",
  runTimeoutSeconds: 480
)
```

Set timeout based on task complexity. 8+ minutes for anything involving research or multi-file changes.

## Post-Completion: Live Preview

For web projects, subagents should spin up a dev server after completing work so changes can be tested live. See the **pr-triage** skill for the full `[POST-COMPLETION]` prompt template and guidelines.

## Prompt Templates

- `references/implementer-prompt.md` — task dispatch template
- `references/spec-reviewer-prompt.md` — spec compliance review
- `references/quality-reviewer-prompt.md` — code quality review
