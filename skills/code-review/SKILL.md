---
name: code-review
description: "Use when implementation is complete and needs verification before merge. Two-stage process: spec compliance first (did you build the right thing?), then code quality (is it well-built?). Also use when receiving review feedback."
---

# Code Review

Two-stage review process. Stage 1 catches wrong work. Stage 2 catches bad work.

## Stage 1: Spec Compliance

**Question:** Did they build what was requested?

Check:
- All requirements implemented (compare spec line by line)
- No missing pieces claimed as complete
- No extra features that weren't requested
- No misinterpretation of requirements

**Do NOT trust the implementer's report.** Read the actual code.

Result: ✅ Spec compliant | ❌ Issues found (with file:line references)

## Stage 2: Code Quality

**Only after spec compliance passes.**

**Question:** Is it well-built?

Check:
- **Architecture** — clear responsibilities, clean interfaces, right-sized files
- **Quality** — clear names, appropriate complexity, proper error handling
- **Testing** — tests verify behavior (not mocks), edge cases covered
- **Patterns** — follows codebase conventions, DRY, YAGNI
- **Safari iOS Compatibility** — if PR touches mobile UI, modals, drawers, date inputs, or fixed-position elements, verify against `safari-ios-mobile` skill rules. Run `bash scripts/safari-lint.sh` if available. Key checks: portals for overlays, no raw date inputs, no 100vh, no body overflow:hidden, no backdrop-blur without md: prefix.
- **Artifacts** — no test/build artifacts committed (`test-results/`, `playwright-report/`, `.last-run.json`, `coverage/`, `.next/`, `dist/`). If found, flag as 🔴 Critical.

Issues by severity:
- 🔴 **Critical** — blocks merge (bugs, security, missing error handling)
- 🟡 **Important** — should fix (unclear code, poor naming, missing tests)
- 🟢 **Minor** — nice to fix (style, minor improvements)

Result: APPROVED | NEEDS_CHANGES

## Receiving Review Feedback

When you receive review feedback:

1. **Read all feedback first** before changing anything
2. **Fix critical issues** immediately
3. **Fix important issues** unless you disagree (explain why)
4. **Fix minor issues** if quick, otherwise note for later
5. **Don't make unrelated changes** during review fixes
6. **Re-run tests** after all fixes

## Review Loop Cap

Max 3 review iterations per task. If still failing after 3, escalate to human with:
- What was requested
- What was built
- What the reviewer flagged
- What was tried
