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
- Edge cases from the spec are handled (not just the happy path)

**Do NOT trust the implementer's report.** Read the actual code.

Result: ✅ Spec compliant | ❌ Issues found (with file:line references)

## Stage 2: Code Quality

**Only after spec compliance passes.**

**Question:** Is it well-built?

### Architecture
- Clear responsibilities — each file/function does one thing
- Clean interfaces — props, return types, API contracts make sense
- Right-sized files — nothing over ~500 lines without good reason
- No god components (doing layout + data fetching + state + business logic)
- Proper separation: server actions vs client components, queries vs mutations

### Security
- **RLS compliance** — all Supabase queries use `createAppClient()` (anon key + cookies + RLS). `createServiceClient()` only where commented with justification (webhooks, cron, registration, marketplace public queries, guest checkout)
- **No credential leaks** — error messages don't expose internal details (table names, column names, stack traces). Use generic messages: "Something went wrong" not "relation tenants does not exist"
- **Input validation** — user inputs validated/sanitized before database or API calls
- **Auth checks** — protected routes verify authentication AND authorization (correct tenant, correct role)
- **No secrets in client code** — `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_SECRET_KEY` never in `"use client"` files or `NEXT_PUBLIC_*` vars
- **Rate limiting** — public-facing endpoints have rate limits

### Data Integrity
- **Atomic operations** — multi-step mutations use transactions or atomic RPCs, not sequential independent calls
- **Race conditions** — concurrent writes handled (optimistic locking, `SELECT ... FOR UPDATE`, unique constraints)
- **Calculation correctness** — money math uses integers (cents), not floats. Verify totals = sum of line items
- **Null handling** — nullable fields handled (not just `value!` assertions)

### Error Handling
- Server actions return structured results, not thrown errors
- Client-side error boundaries for critical paths
- API routes return appropriate HTTP status codes
- Async operations have timeout/retry strategy
- Failed operations don't leave partial state

### Testing
- Tests verify behavior, not implementation (no testing that a mock was called)
- Edge cases covered (empty arrays, null values, boundary conditions)
- Tests actually run — `npx tsc --noEmit && npx vitest run` pass
- No snapshot tests without justification (they rot fast)

### Performance
- No N+1 queries (fetching in loops)
- Large lists paginated
- Images use `next/image` with proper sizing (except team photos — use `<img>` with `object-cover`)
- No unnecessary re-renders (stable references in useEffect deps, no inline objects/arrays)
- Server components where possible (don't add `"use client"` without reason)

### Patterns
- Follows codebase conventions (check nearby files for patterns)
- DRY — but don't over-abstract (duplication is better than the wrong abstraction)
- YAGNI — no speculative features, no unused exports
- Consistent naming — `camelCase` for variables/functions, `PascalCase` for components/types

### Safari iOS Compatibility
If PR touches mobile UI, modals, drawers, date inputs, or fixed-position elements:
- Run `bash scripts/safari-lint.sh` if available
- Verify against `safari-ios-mobile` skill (12 rules)
- Key checks: portals for overlays, no raw date inputs, no `100vh`, no `body.style.overflow = "hidden"`, no `backdrop-blur` without `md:` prefix
- If significant mobile changes: recommend Playwright WebKit smoke test

### Artifacts
- No test/build artifacts committed (`test-results/`, `playwright-report/`, `.last-run.json`, `coverage/`, `.next/`, `dist/`, `node_modules/`)
- If found, flag as 🔴 Critical

### Git Hygiene
- Commit messages are descriptive (not "fix stuff" or "wip")
- No unrelated changes bundled in (separate PRs for separate concerns)
- No force pushes on shared branches
- Branch is up to date with main (or rebased cleanly)

## Issue Severity

- 🔴 **Critical** — blocks merge. Bugs, security issues, data integrity risks, missing error handling, credential leaks, broken builds
- 🟡 **Important** — should fix before merge. Unclear code, poor naming, missing tests, performance issues, accessibility gaps
- 🟢 **Minor** — nice to fix, won't block. Style preferences, minor improvements, documentation gaps

Result: APPROVED | NEEDS_CHANGES (with specific file:line references for each issue)

## Review Output Format

```
## Stage 1: Spec Compliance
✅ Spec compliant (or ❌ with details)

## Stage 2: Code Quality

### 🔴 Critical
- `src/path/file.tsx:42` — [description]

### 🟡 Important  
- `src/path/file.tsx:88` — [description]

### 🟢 Minor
- `src/path/file.tsx:12` — [description]

## Verdict: APPROVED / NEEDS_CHANGES
```

## Receiving Review Feedback

When you receive review feedback:

1. **Read all feedback first** before changing anything
2. **Fix critical issues** immediately
3. **Fix important issues** unless you disagree (explain why)
4. **Fix minor issues** if quick, otherwise note for later
5. **Don't make unrelated changes** during review fixes
6. **Re-run tests** after all fixes
7. **Reply to each review comment** with what you did (or why you didn't)

## Review Loop Cap

Max 3 review iterations per task. If still failing after 3, escalate to human with:
- What was requested
- What was built
- What the reviewer flagged
- What was tried

## Database Migrations

Every PR with a migration MUST include a verification script. Add it to the PR description under a `### Migration Verification` section.

**Template:**
```sql
-- Run after migration to verify all changes applied
SELECT 
  -- Check new columns
  (SELECT count(*) FROM information_schema.columns 
   WHERE table_name = '<table>' AND column_name IN ('<col1>', '<col2>')) as new_columns,
  -- Check new tables
  (SELECT count(*) FROM information_schema.tables 
   WHERE table_name IN ('<new_table>')) as new_tables,
  -- Check new indexes
  (SELECT count(*) FROM pg_indexes 
   WHERE indexname IN ('<index_name>')) as new_indexes,
  -- Check new enum values
  (SELECT count(*) FROM pg_enum 
   WHERE enumlabel IN ('<value>') AND enumtypid = '<enum_type>'::regtype) as new_enums,
  -- Check RLS enabled
  (SELECT rowsecurity FROM pg_tables 
   WHERE tablename = '<table>') as rls_enabled,
  -- Check RLS policies
  (SELECT count(*) FROM pg_policies 
   WHERE tablename = '<table>') as policies,
  -- Check RPCs/functions
  (SELECT count(*) FROM pg_proc 
   WHERE proname IN ('<function_name>')) as rpcs;

-- Expected: <values>
```

**Rules:**
- Verification script goes in the PR description, not a separate file
- Include expected values so the reviewer can compare
- For enum changes: always `ALTER TYPE ... ADD VALUE IF NOT EXISTS` BEFORE any queries using the new value
- For new tables: include column count, RLS status, policy count
- For RPCs: verify they exist in `pg_proc`
- Test the verification query yourself before posting the PR

**Common migration pitfalls:**
- `booking_status` is an **enum type**, not a CHECK constraint — use `ALTER TYPE` not `ALTER TABLE ADD CONSTRAINT`
- `IF NOT EXISTS` on `CREATE TABLE` silently succeeds if table exists with different schema — verify columns match
- `ALTER TABLE ADD COLUMN IF NOT EXISTS` doesn't check column type — a column with the wrong type won't error
- RLS policies with `USING (true)` effectively disable RLS — always scope to tenant
- Consolidated schema (`supabase/consolidated/schema.sql`) must be updated alongside migrations — schema sync tests will fail otherwise

## Common Gotchas (from Renta codebase)

These come up repeatedly — check for them every time:

1. **`createServiceClient()` without comment** — every usage needs a `// Why service role:` comment
2. **Missing tenant isolation** — queries that don't filter by tenant (RLS handles this, but verify the client is correct)
3. **Money as float** — any `price * quantity` should be integer math in cents
4. **`useEffect` with unstable deps** — objects, arrays, or functions created inline cause infinite re-renders
5. **Missing loading states** — async operations need loading indicators
6. **Missing error states** — what happens when the API call fails? Does the UI handle it?
7. **Hardcoded colors** — use brand tokens (`blaze-orange`, `summit-black`, `trail-white`), not hex values
8. **`next/image` with `fill` for photos** — don't use `fill` for team/product photos, use `<img>` with explicit dimensions and `object-cover`
