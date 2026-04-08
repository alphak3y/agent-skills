---
name: writing-plans
description: "Use when you have an approved spec or requirements for a multi-step task, before writing code. Breaks work into bite-sized tasks that an engineer with zero codebase context can follow."
---

# Writing Plans

Break approved specs into tasks so clear that an engineer with zero context and questionable taste can follow them. DRY. YAGNI. Frequent commits.

## Before Writing

**Scope check:** If the spec covers multiple independent subsystems, break into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure First

Before defining tasks, map out which files will be created or modified:
- Each file: one clear responsibility
- Files that change together should live together
- Prefer smaller, focused files — agents reason better about code they can hold in context
- In existing codebases, follow established patterns

## Task Granularity

Each task = 2-10 minutes of focused work. Include:
- Exact file paths (create/modify)
- Complete code (not "add validation")
- Verification steps with expected output
- Commit message

## Plan Template

```markdown
# [Feature] Implementation Plan

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]

---

### Task N: [Name]

**Files:** Create `path/to/file.ts` | Modify `path/to/existing.ts`

- [ ] Step 1: [Action with complete code]
- [ ] Step 2: [Verify — command + expected output]
- [ ] Step 3: [Commit with message]
```

## Testing in Plans

For each feature task, include test steps appropriate to the context:
- **APIs/business logic:** Write failing test → implement → verify pass (TDD)
- **UI components:** Implement → verify visually + check responsiveness
- **Bug fixes:** Write test reproducing bug → fix → verify pass

## Save Location

`docs/plans/YYYY-MM-DD-<feature>.md`

## Execution Handoff

After saving: "Plan complete. Ready to execute?" → transition to `subagent-development` skill.
