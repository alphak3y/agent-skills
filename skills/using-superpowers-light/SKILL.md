---
name: using-superpowers-light
description: "Use at session start to understand the superpowers-light development workflow. Establishes how skills connect: brainstorming → planning → subagent execution → review. Lightweight alternative to obra/superpowers for OpenClaw agents."
---

# Using Superpowers Light

Structured dev workflow: design → plan → execute → review. Each phase has its own skill.

## Skill Map

```
User request → brainstorming → writing-plans → subagent-development
                                                      ↓
                                               code-review (per task)
                                                      ↓
                                               Done (or escalate)

Bug/issue → systematic-debugging → fix → code-review
```

## When Skills Trigger

| Skill | Use When |
|-------|----------|
| `brainstorming` | Building something new, adding features, modifying behavior |
| `writing-plans` | Approved spec exists, need implementation tasks |
| `subagent-development` | Plan exists with independent tasks to execute |
| `code-review` | Implementation complete, needs verification |
| `systematic-debugging` | Bug, test failure, or unexpected behavior |

## Principles

1. **Spec before code** — even "simple" things get a written spec
2. **Fresh context per task** — subagents don't accumulate confusion
3. **Two-stage review** — spec compliance first, code quality second
4. **Root cause before fix** — no guessing at bug fixes
5. **Right-sized rigor** — strict TDD for business logic, visual checks for UI

## Platform: OpenClaw

These skills use `sessions_spawn` for subagent dispatch. Adapt the prompt templates in `subagent-development/references/` if using a different platform.

User instructions (AGENTS.md, CLAUDE.md, direct requests) always override skill guidance.
