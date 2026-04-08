---
name: brainstorming
description: "Use before any creative work — building features, adding components, modifying behavior. Explores intent, requirements, and design before implementation. No code until spec is approved."
---

# Brainstorming Ideas Into Designs

Turn ideas into specs through collaborative dialogue. No code until the spec is signed off.

## Checklist

Complete in order:

1. **Explore context** — read relevant files, docs, recent changes
2. **Ask clarifying questions** — one at a time, prefer multiple choice
3. **Propose 2-3 approaches** — with trade-offs and your recommendation
4. **Present design in sections** — get approval after each section
5. **Write spec** — save to `docs/specs/YYYY-MM-DD-<topic>.md` and commit

## The Process

**Understanding the idea:**
- Check project state first (files, docs, recent commits)
- Assess scope: if request describes multiple independent subsystems, flag it — decompose before detailing
- Ask one question per message
- Focus on: purpose, constraints, success criteria

**Exploring approaches:**
- Propose 2-3 approaches with trade-offs
- Lead with your recommendation and reasoning

**Presenting the design:**
- Scale each section to its complexity (few sentences if simple, more if nuanced)
- Ask after each section if it looks right
- Cover: architecture, components, data flow, error handling, testing approach

**Design for isolation:**
- Small units, one clear purpose each
- Well-defined interfaces between units
- Can someone understand a unit without reading its internals?
- Smaller files = better agent reasoning and more reliable edits

**Existing codebases:**
- Follow established patterns
- Include targeted improvements only where they serve the current goal
- No unrelated refactoring

## Anti-Pattern

"This is too simple for a spec." → That's where unexamined assumptions burn the most time. The spec can be 3 sentences — but write it down.

## After Approval

Write spec to `docs/specs/YYYY-MM-DD-<topic>.md`, then transition to `writing-plans` skill.
