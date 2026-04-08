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

## Prompt Templates

- `references/implementer-prompt.md` — task dispatch template
- `references/spec-reviewer-prompt.md` — spec compliance review
- `references/quality-reviewer-prompt.md` — code quality review
