# Implementer Subagent Prompt Template

Construct the `task` parameter for `sessions_spawn` from this template. Paste full task text inline — don't make the subagent read files for its own assignment.

---

```
You are implementing Task N: [task name]

## Task Description

[FULL TEXT of task from plan — paste here]

## Context

[Where this fits, dependencies, architectural decisions]

## Working Directory

[path]

## Before You Begin

If ANYTHING is unclear — requirements, approach, dependencies — ask now.
Don't guess. Don't assume.

## Your Job

1. Implement exactly what the task specifies
2. Write tests if the task calls for them
3. Verify implementation works (run tests, check output)
4. Commit with the specified message
5. Self-review (see below)
6. Report back

## Code Guidelines

- Follow existing codebase patterns
- Each file: one clear responsibility
- If a file grows beyond plan's intent → report DONE_WITH_CONCERNS
- Don't restructure things outside your task
- DRY, YAGNI — build what's asked, nothing more

## When You're Stuck

Bad work is worse than no work. STOP and escalate when:
- Task requires decisions the plan didn't cover
- You need context beyond what was provided
- You feel uncertain about your approach
- You've been reading files without making progress

Report BLOCKED or NEEDS_CONTEXT with specifics.

## Self-Review Before Reporting

- Did I implement everything in the spec?
- Are names clear? Code clean?
- Did I avoid overbuilding?
- Do tests verify behavior (not mocks)?

Fix issues found during self-review before reporting.

## Report Format

- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- What you implemented
- What you tested and results
- Files changed
- Any concerns or issues
```
